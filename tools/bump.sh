#!/usr/bin/env bash
# Moves the repository to another Singular release.
#   tools/bump.sh vX.Y.Z
# It rewrites the version where it is written by hand (the flake, the README, the kit's script and its readme),
# updates the four Singular inputs of flake.lock, regenerates the Killercoda scenarios, formats and lints.
# Then: review the diff, open a pull request, and once it is merged push the tag vX.Y.Z, which publishes the release.
set -euo pipefail
cd "$(dirname "$0")/.."

new=${1:?usage: tools/bump.sh vX.Y.Z}
[[ "$new" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "the version looks like v0.13.2" >&2
  exit 2
}
old=$(node -p "require('./demos/demo1/version.js')")
if [ "$old" = "$new" ]; then
  echo "already at $new"
  exit 0
fi
gh release view "$new" -R lambdasistemi/singular >/dev/null || {
  echo "Singular has no release $new" >&2
  exit 1
}

pattern=${old//./\\.}
for f in flake.nix README.md kit/demo.sh kit/README.txt; do
  sed -i "s/$pattern/$new/g" "$f"
done

nix flake update source offchain open-datum open-datum-onchain
node demos/demo1/killercoda.js .
bash tools/format.sh write
bash tools/lint.sh

echo
echo "Moved from $old to $new. Left to do: read the diff, open a pull request, and after it is merged push the tag $new."
