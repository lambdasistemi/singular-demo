#!/usr/bin/env bash
# Moves the repository to another Singular release.
#   tools/bump.sh vX.Y.Z
# It rewrites the version where it is written by hand (the flake, the README, the kit's script and its readme, the installer's example),
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
if [ "$old" = "$new" ]; then
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

nix flake update source offchain open-datum open-datum-onchain
bash tools/generate.sh .
bash tools/format.sh write
bash tools/lint.sh

echo
echo "Moved from $old to $new, kit revision 1. Left to do: read the diff, open a pull request, and after it is merged push the tag $new-1."
