#!/usr/bin/env bash
# Moves the repository to another Singular release.
#   tools/bump.sh vX.Y.Z
# It rewrites the version where it is written by hand (the flake, the README, the kit's script and its readme, the installer's example,
# homebrew/singular.env with the new release's macOS bundle checksum),
# starts the kit's revision again at 1 (kit/revision: the kit release is the Singular release and the revision, as in v0.14.0-1),
# updates the four Singular inputs of flake.lock, regenerates the Killercoda scenarios, formats and lints.
# Then: review the diff, open a pull request, and once it is merged push the tag vX.Y.Z-1, which publishes the release.
set -euo pipefail
cd "$(dirname "$0")/.."

new=${1:?usage: tools/bump.sh vX.Y.Z}
[[ "$new" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "the version looks like v0.13.2" >&2
  exit 2
}
old=$(node -p "require('./demos/demo1/version.js')")
old_release=$(node -p "require('./demos/demo1/release.js')")
if [ "$old" = "$new" ] && [ "$(jq -r '.nodes.source.original.ref // ""' flake.lock)" = "$new" ]; then
  echo "already at $new"
  exit 0
fi
gh release view "$new" -R lambdasistemi/singular >/dev/null || {
  echo "Singular has no release $new" >&2
  exit 1
}

# the release names (v0.14.0-1) first, so that the old revision does not stay behind; then the bare version
old_release_pattern=${old_release//./\\.}
pattern=${old//./\\.}
for f in flake.nix README.md kit/demo.sh kit/README.txt demos/demo1/play/install-kit.sh; do
  sed -i -e "s/$old_release_pattern/$new-1/g" -e "s/$pattern/$new/g" "$f"
done
printf '1\n' >kit/revision
# A preparation commit may name the target release while its source still uses a commit pin.
sed -i -E "s|(github:lambdasistemi/singular/)[0-9a-f]{40}|\1$new|g" flake.nix

# homebrew/singular.env names the pinned Singular release's macOS bundle for the versioned Homebrew formula:
# the bare version and the bundle's checksum from the new release's SHA256SUMS.
bare_new=${new#v}
sums=$(mktemp)
trap 'rm -f "$sums"' EXIT
curl -fsSL --retry 3 -o "$sums" "https://github.com/lambdasistemi/singular/releases/download/$new/SHA256SUMS"
sha=$(awk "/singular-$bare_new-aarch64-darwin.tar.gz\$/ {print \$1}" "$sums")
[ -n "$sha" ] || {
  echo "Singular release $new has no macOS bundle checksum in SHA256SUMS" >&2
  exit 1
}
sed -i "s/^SINGULAR_VERSION=.*/SINGULAR_VERSION=$bare_new/" homebrew/singular.env
sed -i "s/^SINGULAR_SHA=.*/SINGULAR_SHA=$sha/" homebrew/singular.env

nix flake update source offchain open-datum open-datum-onchain
bash tools/generate.sh .
bash tools/format.sh write
bash tools/lint.sh

echo
echo "Moved from $old to $new, kit revision 1. Left to do: read the diff, open a pull request, and after it is merged push the tag $new-1."
