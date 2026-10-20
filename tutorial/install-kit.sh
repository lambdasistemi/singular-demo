#!/usr/bin/env bash
# Installs the kit of the release this repository is pinned to, with the play's own installer
# (demos/demo1/play/install-kit.sh), which checks it against the release's SHA256SUMS.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
version=$(node -p "require('$root/demos/demo1/version.js')")
exec bash "$root/demos/demo1/play/install-kit.sh" "$version" "$HOME"
