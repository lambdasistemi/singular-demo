# The Ubuntu kit: one tarball that runs Demo 1 with no Nix on the target.
# Every input comes from flake.lock. The output holds the tarball and its
# SHA256SUMS; the tarball is byte-for-byte reproducible (fixed modification
# time, sorted names, no gzip name/time field).
{
  pkgs,
  singular,
  openDatum,
  devnet,
  cardanoNode,
  source,
  blueprint,
  txTools,
}:
let
  version = pkgs.lib.removeSuffix "\n" (builtins.readFile (source + "/version.txt"));
  kitName = "singular-demo-v${version}-x86_64-linux";
in
pkgs.runCommand "singular-demo-kit-${version}"
  {
    nativeBuildInputs = [
      pkgs.patchelf
      pkgs.binutils
      pkgs.pkgsStatic.stdenv.cc
      pkgs.gnutar
      pkgs.gzip
      pkgs.gnused
      pkgs.gawk
      pkgs.findutils
      pkgs.gnugrep
      pkgs.coreutils
    ];
    inherit
      singular
      openDatum
      devnet
      cardanoNode
      source
      blueprint
      txTools
      ;
    jq = pkgs.pkgsStatic.jq.bin;
    curl = pkgs.pkgsStatic.curl.bin;
    inherit version kitName;
    commit = source.rev;
    nodeVersion = pkgs.lib.getVersion cardanoNode;
    launcher = ./launcher.c;
    readme = ./README.txt;
    demo = ./demo.sh;
  }
  ''
    set -euo pipefail
    SOURCE_DATE_EPOCH=1
    SING=$singular/bin/singular
    OD=$openDatum/bin/open-datum
    # the devnet package is a wrapper script: it names the real executable
    DEVNET_REAL=$(sed -n 's/^exec "\(.*\)"  "\$@".*/\1/p' "$devnet/bin/devnet")
    NODE=$cardanoNode/bin/cardano-node
    # the packaged data directory is named inside the singular executable
    DATA=$(grep -ao '/nix/store/[a-z0-9]*-singular-registry-lib-local-services-[^/ ]*-data' "$SING" | sort -u)
    [ "$(printf '%s\n' "$DATA" | wc -l)" = 1 ] || { echo "expected exactly one packaged data path in singular, got: $DATA" >&2; exit 1; }
    DATA=$(echo "$DATA"/share/ghc-*/x86_64-linux-ghc-*-inplace/singular-registry-*)
    for f in "$SING" "$OD" "$DEVNET_REAL" "$NODE" "$DATA/data" "$blueprint" "$source/version.txt"; do
      test -e "$f" || { echo "missing $f" >&2; exit 1; }
    done

    W=$PWD/stage
    OUT=$W/$kitName
    mkdir -p "$OUT"/{bin,libexec,lib/main,lib/node,share}

    # real executables
    cp -L --no-preserve=mode "$SING" "$OUT/libexec/singular"
    cp -L --no-preserve=mode "$OD" "$OUT/libexec/open-datum"
    cp -L --no-preserve=mode "$DEVNET_REAL" "$OUT/libexec/devnet"
    cp -L --no-preserve=mode "$NODE" "$OUT/libexec/cardano-node"
    chmod u+w "$OUT"/libexec/*

    # what the executable's own loader resolves for it (same listing ldd prints)
    needed() { "$(patchelf --print-interpreter "$1")" --list "$1"; }
    for exe in "$SING" "$OD" "$DEVNET_REAL" "$NODE"; do
      if needed "$exe" | grep -q 'not found'; then echo "unresolved library for $exe" >&2; needed "$exe" >&2; exit 1; fi
    done

    # libraries: everything the loader names, plus glibc's name-service and resolver libraries
    copyset() { # dir exe...
      local dir=$1; shift
      for exe in "$@"; do
        needed "$exe" | awk '/=> \//{print $3} /^\t\//{print $1}' | while read -r lib; do
          case "$(basename "$lib")" in ld-linux*) continue;; esac
          cp -L --no-preserve=mode "$lib" "$OUT/lib/$dir/$(basename "$lib")"
        done
      done
    }
    copyset main "$SING" "$OD" "$DEVNET_REAL"
    copyset node "$NODE"
    # the loader is named by its soname inside lib/<set>
    glibc_main=$(needed "$SING" | awk '/libc.so.6/{print $3}' | xargs dirname)
    glibc_node=$(needed "$NODE" | awk '/libc.so.6/{print $3}' | xargs dirname)
    cp -L --no-preserve=mode "$glibc_main/ld-linux-x86-64.so.2" "$OUT/lib/main/"
    cp -L --no-preserve=mode "$glibc_node/ld-linux-x86-64.so.2" "$OUT/lib/node/"
    for l in libnss_files.so.2 libnss_dns.so.2 libresolv.so.2; do
      cp -L --no-preserve=mode "$glibc_main/$l" "$OUT/lib/main/$l"
      cp -L --no-preserve=mode "$glibc_node/$l" "$OUT/lib/node/$l"
    done
    # one locale per library set, matching that set's C library
    for set in main node; do
      g=glibc_$set
      mkdir -p "$OUT/lib/$set/locale"
      cp -r --no-preserve=mode "''${!g}/locale/C.utf8" "$OUT/lib/$set/locale/C.utf8"
    done
    chmod -R u+w "$OUT"; chmod 755 "$OUT"/libexec/* "$OUT"/lib/*/ld-linux-x86-64.so.2

    # no store paths in the kit: drop RUNPATHs (the loader is invoked explicitly)
    for f in "$OUT"/libexec/* "$OUT"/lib/*/*.so*; do
      case "$(basename "$f")" in ld-linux*) continue;; esac
      patchelf --remove-rpath "$f" 2>/dev/null || true
    done

    # data
    mkdir -p "$OUT/share/singular-registry"
    cp -rL --no-preserve=mode "$DATA/data" "$OUT/share/singular-registry/data"
    cp -rL --no-preserve=mode "$source/offchain/e2e-test/genesis" "$OUT/share/genesis"
    cp "$blueprint" "$OUT/share/plutus.json"; cp "$source/version.txt" "$OUT/share/version.txt"
    chmod -R u+w "$OUT/share"

    # launcher (static, musl) installed under the four program names, plus static jq and curl
    x86_64-unknown-linux-musl-gcc -O2 -static -Wall -o "$W/launcher" "$launcher"
    strip "$W/launcher"
    for n in singular open-datum devnet cardano-node; do cp "$W/launcher" "$OUT/bin/$n"; done
    cp --no-preserve=mode "$txTools/bin/tx-inspect" "$txTools/bin/tx-diff" "$OUT/bin/"
    cp --no-preserve=mode "$jq/bin/jq" "$OUT/bin/jq"
    cp --no-preserve=mode "$curl/bin/curl" "$OUT/bin/curl"
    chmod u+w "$OUT"/bin/*
    # jq and curl are static; their compiled-in install paths are dead text.
    # Same-length rewrite so no store path is left in bin/.
    LC_ALL=C sed -i 's|/nix/store/|/nonexist//|g' "$OUT/bin/jq" "$OUT/bin/curl"
    chmod 755 "$OUT"/bin/*

    printf '%s\n' "singular v$version" "commit $commit" "cardano-node $nodeVersion" > "$OUT/VERSION"
    cp "$readme" "$OUT/README.txt"
    cp "$demo" "$OUT/demo.sh"; chmod 755 "$OUT/demo.sh"

    # pack: fixed time, sorted names, no owner, no gzip name/time field
    mkdir -p "$out"
    tar --owner=0 --group=0 --numeric-owner --sort=name --mtime="@$SOURCE_DATE_EPOCH" \
        -C "$W" -cf - "$kitName" | gzip -n -9 > "$out/$kitName.tar.gz"
    ( cd "$out" && sha256sum "$kitName.tar.gz" > SHA256SUMS && sha256sum -c SHA256SUMS )
  ''
