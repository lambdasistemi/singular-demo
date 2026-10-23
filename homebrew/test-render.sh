#!/usr/bin/env bash
# Test that the Homebrew formulas render from their templates.
#   homebrew/test-render.sh
# Renders both formulas with pinned test values into a temporary directory
# and asserts the shaped content: dependencies, archive urls, checksums and
# the play command. Exit 0 only if every check holds.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail=0
check() { # description, test result (0 = holds)
  if [ "$2" -eq 0 ]; then echo "  ok    $1"; else
    echo "  FAIL  $1"
    fail=1
  fi
}

# Pinned test values (not releases): the shape is what is tested, not the data.
TAG=v0.16.0-1
SINGULAR_VERSION=0.16.0
SINGULAR_SHA=920fe4b606077446baba294e84e84294733c87cab9682576d10b7df3e63735b7
KIT_SHA=0000000000000000000000000000000000000000000000000000000000000000
TOOLS_SHA=1111111111111111111111111111111111111111111111111111111111111111

status() { "$@" >/dev/null 2>&1 && echo 0 || echo 1; }

bash "$here/render.sh" --tag "$TAG" \
  --singular-version "$SINGULAR_VERSION" --singular-sha "$SINGULAR_SHA" \
  --kit-sha "$KIT_SHA" --tools-sha "$TOOLS_SHA" --out "$work" >/dev/null
check "render.sh exits 0" $?

singular="$work/singular@0.16.rb"
demo="$work/singular-demo.rb"
check "singular@0.16.rb is rendered" "$(status test -s "$singular")"
check "singular-demo.rb is rendered" "$(status test -s "$demo")"

# The versioned Singular formula: the macOS bundle of the pinned release.
check "versioned formula names the v0.16.0 macOS bundle" "$(
  grep -q "singular/releases/download/v$SINGULAR_VERSION/singular-$SINGULAR_VERSION-aarch64-darwin.tar.gz" "$singular"
  echo $?
)"
check "versioned formula carries that bundle's checksum" "$(
  grep -q "$SINGULAR_SHA" "$singular"
  echo $?
)"

# The demo formula: its dependencies, its archive, its play command.
for dep in 'depends_on "lambdasistemi/tap/singular@0.16"' 'depends_on "lambdasistemi/tap/tx-inspect"' 'depends_on "lambdasistemi/tap/tx-diff"' 'depends_on "jq"' 'depends_on "tmux"' 'depends_on "lambdasistemi/tap/tutorial-stepper"'; do
  check "singular-demo depends on $dep" "$(
    grep -qF "$dep" "$demo"
    echo $?
  )"
done
check "demo formula fetches this repository's tag tarball" "$(
  grep -q "singular-demo/archive/refs/tags/$TAG.tar.gz" "$demo"
  echo $?
)"
check "demo formula carries that tarball's checksum" "$(
  grep -q "$KIT_SHA" "$demo"
  echo $?
)"
check "demo formula installs both tutorials" "$(
  grep -q "demo1" "$demo" && grep -q "pay-by-name" "$demo"
  echo $?
)"
check "demo formula plays Demo 1 with tutorial-stepper play" "$(
  grep -q "tutorial-stepper play" "$demo"
  echo $?
)"
auto_pat="play \$auto"
check "demo wrapper hoists a leading --auto" "$(status grep -qF "$auto_pat" "$demo")"
check "demo formula fetches the pay-by-name tools resource" "$(
  grep -q "pay-by-name-tools-$TAG.tar.gz" "$demo"
  echo $?
)"
check "demo formula carries the tools checksum" "$(
  grep -q "$TOOLS_SHA" "$demo"
  echo $?
)"
check "demo formula installs sink-tools" "$(
  grep -q "sink-tools" "$demo"
  echo $?
)"

# The --local mode (the pull-request job) points both archives at fresh local tarballs,
# with checksums computed from those files; only the urls differ from the release render.
echo kit >"$work/kit.tar.gz"
echo tools >"$work/tools.tar.gz"
local_work=$(mktemp -d)
trap 'rm -rf "$work" "$local_work"' EXIT
bash "$here/render.sh" --tag "$TAG" \
  --singular-version "$SINGULAR_VERSION" --singular-sha "$SINGULAR_SHA" \
  --local "$work/kit.tar.gz" --tools-local "$work/tools.tar.gz" --out "$local_work" >/dev/null
check "local render exits 0" $?
kit_sha=$(sha256sum "$work/kit.tar.gz" | cut -d' ' -f1)
tools_sha=$(sha256sum "$work/tools.tar.gz" | cut -d' ' -f1)
check "local render points the demo archive at the local tarball" "$(
  grep -qF "file://$work/kit.tar.gz" "$local_work/singular-demo.rb"
  echo $?
)"
check "local render checks the local tarball" "$(
  grep -q "$kit_sha" "$local_work/singular-demo.rb"
  echo $?
)"
check "local render points the tools resource at the local tarball" "$(
  grep -qF "file://$work/tools.tar.gz" "$local_work/singular-demo.rb"
  echo $?
)"
check "local render checks the local tools" "$(
  grep -q "$tools_sha" "$local_work/singular-demo.rb"
  echo $?
)"
check "local render leaves the Singular bundle alone" "$(
  grep -q "$SINGULAR_SHA" "$local_work/singular@0.16.rb"
  echo $?
)"

# The macOS fallback: with no sha256sum on PATH, --local checksums come from shasum -a 256.
# The sandbox has bash and the text tools but no sha256sum; shasum is a double for macOS shasum.
# dirname ships with macOS (and the sandbox's coreutils); it is linked like the rest.
macbin=$(mktemp -d)
for t in bash dirname sed grep cut mkdir cp mv wc; do
  ln -s "$(command -v "$t")" "$macbin/$t"
done
cat >"$macbin/shasum" <<EOF
#!/usr/bin/env bash
# Test double for macOS shasum: drops its own flags, checksums the named file.
file=
for arg in "\$@"; do file=\$arg; done
exec "$(command -v sha256sum)" "\$file"
EOF
chmod +x "$macbin/shasum"
mac_out=$(mktemp -d)
trap 'rm -rf "$work" "$local_work" "$macbin" "$mac_out"' EXIT
PATH="$macbin" bash "$here/render.sh" --tag "$TAG" \
  --singular-version "$SINGULAR_VERSION" --singular-sha "$SINGULAR_SHA" \
  --local "$work/kit.tar.gz" --tools-local "$work/tools.tar.gz" --out "$mac_out" >/dev/null
check "render without sha256sum exits 0" $?
check "fallback checksums the local tarball" "$(
  grep -q "$kit_sha" "$mac_out/singular-demo.rb"
  echo $?
)"
check "fallback checksums the local tools" "$(
  grep -q "$tools_sha" "$mac_out/singular-demo.rb"
  echo $?
)"

exit $fail
