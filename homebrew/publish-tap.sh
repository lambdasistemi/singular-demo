#!/usr/bin/env bash
# Publishes the Homebrew formulas for a release tag, from inside the dev shell.
#   homebrew/publish-tap.sh --tag TAG [--dry-run] [--out DIR]
# Fetches the tag's archive and its pay-by-name tools, renders both formulas
# with homebrew/render.sh, and pushes them to lambdasistemi/homebrew-tap.
# --dry-run renders both formulas from the published tag and pushes nothing
# (no tap token needed). --out keeps the rendered formulas in DIR (default: a
# temporary directory named on standard output). Exit 0 only if both formulas
# are rendered (and, without --dry-run, pushed); a tag whose release or tools
# tarball is missing fails. Every tool this script calls (curl, sha256sum, git,
# gh) comes from the dev shell: run it as `nix develop .#dev --command bash
# homebrew/publish-tap.sh ...`, never on the runner's own PATH.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091 # singular.env names the pinned Singular release's macOS bundle
source "$here/singular.env"

tag=""
dry_run=0
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tag)
      tag=${2:?}
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
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
[ -n "$tag" ] || {
  echo "usage: publish-tap.sh --tag TAG [--dry-run] [--out DIR]" >&2
  exit 2
}
if [ "$dry_run" -eq 0 ]; then
  [ -n "${TAP_TOKEN:-}" ] || {
    echo "TAP_TOKEN is required to publish (the workflow mints it from the org app)" >&2
    exit 2
  }
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL --retry 3 -o "$tmp/repo.tar.gz" \
  "https://github.com/lambdasistemi/singular-demo/archive/refs/tags/$tag.tar.gz"
curl -fsSL --retry 3 -o "$tmp/tools.tar.gz" \
  "https://github.com/lambdasistemi/singular-demo/releases/download/$tag/pay-by-name-tools-$tag.tar.gz"
kit_sha=$(sha256sum "$tmp/repo.tar.gz" | cut -d' ' -f1)
tools_sha=$(sha256sum "$tmp/tools.tar.gz" | cut -d' ' -f1)
formulas="$tmp/Formula"
[ -z "$out" ] || formulas="$out"
mkdir -p "$formulas"
bash "$here/render.sh" --tag "$tag" \
  --singular-version "$SINGULAR_VERSION" --singular-sha "$SINGULAR_SHA" \
  --kit-sha "$kit_sha" --tools-sha "$tools_sha" --out "$formulas"
echo "rendered $formulas/singular@0.16.rb"
echo "rendered $formulas/singular-demo.rb"
if [ "$dry_run" -eq 1 ]; then
  echo "dry run: pushed nothing"
  exit 0
fi
git clone "https://x-access-token:${TAP_TOKEN}@github.com/lambdasistemi/homebrew-tap.git" "$tmp/tap"
cp "$formulas/singular@0.16.rb" "$formulas/singular-demo.rb" "$tmp/tap/Formula/"
cd "$tmp/tap" || exit 1
git config user.name "github-actions"
git config user.email "actions@github.com"
git add "Formula/singular@0.16.rb" Formula/singular-demo.rb
if git diff --cached --quiet; then
  echo "formulas unchanged: committed nothing"
else
  git commit -m "singular-demo $tag: singular@0.16 and singular-demo"
fi
git push
