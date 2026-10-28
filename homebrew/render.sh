#!/usr/bin/env bash
# Renders the Homebrew formulas from their templates.
#   homebrew/render.sh --tag TAG --singular-version V --singular-sha SHA --kit-sha SHA --out DIR
#     the release render: archive urls are built from the tag, checksums are given
#   homebrew/render.sh --tag TAG --singular-version V --singular-sha SHA --local KIT_TARBALL --out DIR
#     the pull-request render: the archive points at a fresh local tarball (file://), checksums computed from them
# Writes DIR/singular@VERSION_SERIES.rb and DIR/singular-demo.rb. Exit 0 only if both are written.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

tag=""
singular_version=""
singular_sha=""
kit_sha=""
local_kit=""
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tag)
      tag=${2:?}
      shift 2
      ;;
    --singular-version)
      singular_version=${2:?}
      shift 2
      ;;
    --singular-sha)
      singular_sha=${2:?}
      shift 2
      ;;
    --kit-sha)
      kit_sha=${2:?}
      shift 2
      ;;
    --local)
      local_kit=${2:?}
      shift 2
      ;;
    --out)
      out=${2:?}
      shift 2
      ;;
    *)
      echo "unknown argument $1" >&2
      exit 2
      ;;
  esac
done
[ -n "$tag" ] && [ -n "$singular_version" ] && [ -n "$singular_sha" ] && [ -n "$out" ] || {
  echo "usage: render.sh --tag TAG --singular-version V --singular-sha SHA (--kit-sha SHA | --local KIT) --out DIR" >&2
  exit 2
}
if [ -n "$local_kit" ]; then
  [ -z "$kit_sha" ] || {
    echo "--local goes without --kit-sha" >&2
    exit 2
  }
  case "$local_kit" in /*) ;; *) local_kit=$PWD/$local_kit ;; esac
else
  [ -n "$kit_sha" ] || {
    echo "--kit-sha is required without --local" >&2
    exit 2
  }
fi

version=${tag#v}
repo=https://github.com/lambdasistemi/singular-demo
sha256file() { # FILE: its hex checksum, with sha256sum or, on macOS, shasum -a 256
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}
if [ -n "$local_kit" ]; then
  kit_url=file://$local_kit
  kit_sha=$(sha256file "$local_kit")
else
  kit_url=$repo/archive/refs/tags/$tag.tar.gz
fi
series=${singular_version%.*}
formula="$out/singular@$series.rb"
class="SingularAT${series//./}"
singular_url=https://github.com/lambdasistemi/singular/releases/download/v$singular_version/singular-$singular_version-aarch64-darwin.tar.gz

mkdir -p "$out"
sub() { # placeholder value file...: escape sed metacharacters in the value, replace without sed -i
  # (BSD sed needs a backup suffix for -i, so the rendering writes a temporary file instead)
  what=$1
  value=$(printf '%s' "$2" | sed -e 's/[&|\\]/\\&/g')
  sed "s|$what|$value|g" "$3" >"$3.rendered" && mv "$3.rendered" "$3"
}
cp "$here/singular.rb.in" "$formula"
sub @SINGULAR_CLASS@ "$class" "$formula"
sub @SINGULAR_URL@ "$singular_url" "$formula"
sub @SINGULAR_SHA@ "$singular_sha" "$formula"
sub @SINGULAR_VERSION@ "$singular_version" "$formula"
cp "$here/singular-demo.rb.in" "$out/singular-demo.rb"
sub @KIT_URL@ "$kit_url" "$out/singular-demo.rb"
sub @KIT_SHA@ "$kit_sha" "$out/singular-demo.rb"
sub @VERSION@ "$version" "$out/singular-demo.rb"
sub @SINGULAR_SERIES@ "$series" "$out/singular-demo.rb"
leftovers=$(grep -h -o '@[A-Z_]*@' "$formula" "$out/singular-demo.rb" | wc -l || true)
[ "$leftovers" -eq 0 ] || {
  echo "unrendered placeholders remain:" >&2
  grep -n '@[A-Z_]*@' "$formula" "$out/singular-demo.rb" >&2
  exit 1
}
