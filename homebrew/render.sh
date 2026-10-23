#!/usr/bin/env bash
# Renders the Homebrew formulas from their templates.
#   homebrew/render.sh --tag TAG --singular-version V --singular-sha SHA --kit-sha SHA --tools-sha SHA --out DIR
#     the release render: archive urls are built from the tag, checksums are given
#   homebrew/render.sh --tag TAG --singular-version V --singular-sha SHA --local KIT_TARBALL --tools-local TOOLS_TARBALL --out DIR
#     the pull-request render: both archives point at fresh local tarballs (file://), checksums computed from them
# Writes DIR/singular@0.16.rb and DIR/singular-demo.rb. Exit 0 only if both are written.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

tag=""
singular_version=""
singular_sha=""
kit_sha=""
tools_sha=""
local_kit=""
local_tools=""
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tag) tag=${2:?}; shift 2 ;;
    --singular-version) singular_version=${2:?}; shift 2 ;;
    --singular-sha) singular_sha=${2:?}; shift 2 ;;
    --kit-sha) kit_sha=${2:?}; shift 2 ;;
    --tools-sha) tools_sha=${2:?}; shift 2 ;;
    --local) local_kit=${2:?}; shift 2 ;;
    --tools-local) local_tools=${2:?}; shift 2 ;;
    --out) out=${2:?}; shift 2 ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -n "$tag" ] && [ -n "$singular_version" ] && [ -n "$singular_sha" ] && [ -n "$out" ] || {
  echo "usage: render.sh --tag TAG --singular-version V --singular-sha SHA (--kit-sha SHA --tools-sha SHA | --local KIT --tools-local TOOLS) --out DIR" >&2
  exit 2
}
if [ -n "$local_kit" ] || [ -n "$local_tools" ]; then
  [ -n "$local_kit" ] && [ -n "$local_tools" ] || { echo "--local and --tools-local go together" >&2; exit 2; }
  [ -z "$kit_sha" ] && [ -z "$tools_sha" ] || { echo "--local goes without --kit-sha/--tools-sha" >&2; exit 2; }
else
  [ -n "$kit_sha" ] && [ -n "$tools_sha" ] || { echo "--kit-sha and --tools-sha go together" >&2; exit 2; }
fi

version=${tag#v}
repo=https://github.com/lambdasistemi/singular-demo
if [ -n "$local_kit" ]; then
  kit_url=file://$local_kit
  kit_sha=$(sha256sum "$local_kit" | cut -d' ' -f1)
  tools_url=file://$local_tools
  tools_sha=$(sha256sum "$local_tools" | cut -d' ' -f1)
else
  kit_url=$repo/archive/refs/tags/$tag.tar.gz
  tools_url=$repo/releases/download/$tag/pay-by-name-tools-$tag.tar.gz
fi
singular_url=https://github.com/lambdasistemi/singular/releases/download/v$singular_version/singular-$singular_version-aarch64-darwin.tar.gz

mkdir -p "$out"
sub() { # placeholder value file...: escape sed metacharacters in the value, replace in the file
  what=$1
  value=$(printf '%s' "$2" | sed -e 's/[&|\\]/\\&/g')
  sed -i "s|$what|$value|g" "$3"
}
cp "$here/singular-at-0.16.rb.in" "$out/singular@0.16.rb"
sub @SINGULAR_URL@ "$singular_url" "$out/singular@0.16.rb"
sub @SINGULAR_SHA@ "$singular_sha" "$out/singular@0.16.rb"
sub @SINGULAR_VERSION@ "$singular_version" "$out/singular@0.16.rb"
cp "$here/singular-demo.rb.in" "$out/singular-demo.rb"
sub @KIT_URL@ "$kit_url" "$out/singular-demo.rb"
sub @KIT_SHA@ "$kit_sha" "$out/singular-demo.rb"
sub @TOOLS_URL@ "$tools_url" "$out/singular-demo.rb"
sub @TOOLS_SHA@ "$tools_sha" "$out/singular-demo.rb"
sub @VERSION@ "$version" "$out/singular-demo.rb"
leftovers=$(grep -h -o '@[A-Z_]*@' "$out/singular@0.16.rb" "$out/singular-demo.rb" | wc -l || true)
[ "$leftovers" -eq 0 ] || {
  echo "unrendered placeholders remain:" >&2
  grep -n '@[A-Z_]*@' "$out/singular@0.16.rb" "$out/singular-demo.rb" >&2
  exit 1
}
