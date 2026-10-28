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
hits=$(grep -arl '/nix/store' "$K/bin" "$K/share" "$K/demo.sh" "$K/README.txt" "$K/VERSION" | wc -l)
echo "files under bin/, share/ and the top files naming /nix/store: $hits"
check "no store path in bin/, share/, demo.sh, README.txt, VERSION" $((hits != 0))

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

status() { "$@" >/dev/null 2>&1 && echo 0 || echo 1; }

# tutorial-stepper and the tutorial: the kit plays with the stepper, drive.sh is gone
for f in bin/tutorial-stepper share/tutorials/demo1/tutorial.toml share/tutorials/demo1/setup.sh; do
  check "$f is in the kit" "$(status test -s "$K/$f")"
done
check "bin/tutorial-stepper is executable" "$(status test -x "$K/bin/tutorial-stepper")"
if readelf -l "$K/bin/tutorial-stepper" 2>/dev/null | grep -qi 'interp'; then interp=1; else interp=0; fi
check "bin/tutorial-stepper is statically linked" $interp
got=$("$K/bin/tutorial-stepper" --version 2>&1)
echo "bin/tutorial-stepper --version: $got"
check "the kit's tutorial-stepper is 0.4.1" "$(
  echo "$got" | grep -q 'tutorial-stepper 0.4.1'
  echo $?
)"
"$K/bin/tutorial-stepper" check "$K/share/tutorials/demo1" >/dev/null 2>&1
check "the carried demo1 tutorial checks" $?
check "drive.sh is gone from the kit" "$(status test ! -e "$K/drive.sh")"

echo "files in the kit: $(find "$K" -type f | wc -l)"
exit $fail
