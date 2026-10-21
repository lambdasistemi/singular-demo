#!/usr/bin/env bash
# Checks of the built kit tarball (no container). Exit 0 only if every check holds.
#   KIT_DIR   directory holding the tarball and SHA256SUMS (the kit package, or dist/)
# Needs: sha256sum, tar, gzip, grep, readelf (binutils).
set -uo pipefail
KIT_DIR=${KIT_DIR:?directory with the tarball and SHA256SUMS}
tarball=$(ls "$KIT_DIR"/*.tar.gz)
fail=0
check() { # description, test result (0 = holds)
  if [ "$2" -eq 0 ]; then echo "  ok    $1"; else
    echo "  FAIL  $1"
    fail=1
  fi
}
work=$(mktemp -d)
trap 'chmod -R u+w "$work"; rm -rf "$work"' EXIT
tar xzf "$tarball" -C "$work"
K=$(echo "$work"/*)

echo "# kit verification of $(basename "$tarball")"
(cd "$KIT_DIR" && sha256sum -c SHA256SUMS)
check "sha256 of the tarball matches SHA256SUMS" $?

n=$(tar tzf "$tarball" | grep -c /nix || true)
echo "file names inside the archive containing /nix: $n"
check "no file name contains /nix" $((n != 0))

# -a reads binary files as text (plain grep can skip a binary after its first odd byte)
hits=$(grep -arl '/nix/store' "$K/bin" "$K/share" "$K/demo.sh" "$K/drive.sh" "$K/README.txt" "$K/VERSION" | wc -l)
echo "files under bin/, share/ and the top files naming /nix/store: $hits"
check "no store path in bin/, share/, demo.sh, drive.sh, README.txt, VERSION" $((hits != 0))

# control: the same search over libexec/ must find something, or the check above could not fail
ctl=$(grep -arl '/nix/store' "$K/libexec" | wc -l)
echo "control, same search over libexec/: $ctl files"
check "control search can return a hit" $((ctl == 0))

libs=$(grep -arl '/nix/store' "$K/lib" | wc -l)
total=$(find "$K/lib" -name '*.so*' | wc -l)
echo "library files with a store path as dead text (the C library's compiled-in paths): $libs of $total"

rp=0
m=0
for f in "$K"/libexec/* "$K"/lib/*/*.so*; do
  case "$(basename "$f")" in ld-linux*) continue ;; esac
  m=$((m + 1))
  rp=$((rp + $(readelf -d "$f" 2>/dev/null | grep -ci 'rpath\|runpath')))
done
echo "RPATH/RUNPATH entries over $m files in libexec/ and lib/: $rp"
check "no RPATH/RUNPATH entry" $((rp != 0))

# the tools of the pay-by-name scenario: present, and the bundle runs with node alone and carries the compiled validator
status() { "$@" >/dev/null 2>&1 && echo 0 || echo 1; }
for f in bin/sink-tools share/sink-tools/sink-tools.cjs share/sink-tools/plutus.json; do
  check "$f is in the kit" "$(status test -s "$K/$f")"
done
check "bin/sink-tools is executable" "$(status test -x "$K/bin/sink-tools")"
if command -v node >/dev/null; then
  # the sink of the name alice under a fixed active policy: its script hash pins the compiled validator the bundle carries
  got=$("$K/bin/sink-tools" sink-address --active-policy 1ea53ee2878802fce8f05958db13186e49a3c179f7c2f1f446834577 --name alice | grep '"scriptHash"' | cut -d'"' -f4)
  echo "sink-tools sink-address, script hash: $got"
  check "sink-tools runs with node alone and its sink script hash is the expected one" "$(status test "$got" = 9946eda863be029e31bdfc7ce24ef111c270eda863c7faa84be25f08)"
  # control: the same command with the blueprint beside the bundle must give the same hash, or one of the two files is not the other
  beside=$(SINK_BLUEPRINT="$K/share/sink-tools/plutus.json" "$K/bin/sink-tools" sink-address --active-policy 1ea53ee2878802fce8f05958db13186e49a3c179f7c2f1f446834577 --name alice | grep '"scriptHash"' | cut -d'"' -f4)
  check "the blueprint beside the bundle and the one inside it give the same script hash" "$(status test "$beside" = "$got")"
else
  echo "no node on this machine: the run of sink-tools is not checked"
  check "node is available to run sink-tools" 1
fi

echo "files in the kit: $(find "$K" -type f | wc -l)"
exit $fail
