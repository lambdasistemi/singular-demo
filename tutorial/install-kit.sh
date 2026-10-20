#!/usr/bin/env bash
set -euo pipefail
version=v0.13.0
archive="singular-demo-${version}-x86_64-linux.tar.gz"
target="$HOME/singular-demo-${version}-x86_64-linux"
expected=b4169828f2ea923342bf6887f81c916df350b715d852b6b467220423882945cd
if [[ -x "$target/bin/singular" && -f "$target/.tutorial-verified" ]]; then
  echo "Singular kit already installed: $target"
  exit 0
fi
if [[ -e "$target" ]]; then
  echo "An unverified kit already exists at $target. Move it aside before retrying." >&2
  exit 1
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl --fail --location --retry 3 \
  "https://github.com/lambdasistemi/singular-demo/releases/download/$version/$archive" \
  -o "$tmp/$archive"
printf '%s  %s\n' "$expected" "$tmp/$archive" | sha256sum -c -
tar -xzf "$tmp/$archive" -C "$tmp"
mv "$tmp/singular-demo-${version}-x86_64-linux" "$target"
touch "$target/.tutorial-verified"
echo "Kit verified and installed. Continue to the walkthrough."
