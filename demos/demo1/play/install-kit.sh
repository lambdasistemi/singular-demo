#!/usr/bin/env bash
# Installs Singular's own release for Linux on x86_64, with no Nix: the relocatable tarball (the programs, the
# development node and its genesis files) and, from the on-chain archive, the blueprint the commands take.
# Both are checked against the release's SHA256SUMS. Every environment of the play (Killercoda, Codespaces, the
# tests) installs with this script.
#   install-kit.sh VERSION [DIR]
#     VERSION   the release, for example v0.13.2
#     DIR       where the release folder goes (default: $HOME)
#   PLAY_KIT_BASE   takes the files from this address instead of the release page; file:///dir holds the tarball,
#                   the on-chain archive and SHA256SUMS of a release that is not published yet
# The folder is singular-NUMBER-x86_64-linux/. share/plutus.json and share/version.txt are put beside the
# programs' own files, where the shell setup looks for them.
set -euo pipefail
version=${1:?usage: install-kit.sh VERSION [DIR]}
dir=${2:-$HOME}
number=${version#v}
base=${PLAY_KIT_BASE:-https://github.com/lambdasistemi/singular/releases/download/$version}
name=singular-$number-x86_64-linux
onchain=singular-onchain-$number

# the tutorial's commands read receipts with jq and ask the chain's web API with curl
missing=()
for tool in jq curl; do
  command -v "$tool" >/dev/null || missing+=("$tool")
done
if [ "${#missing[@]}" -gt 0 ]; then
  if [ "$(id -u)" = 0 ]; then
    apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}"
  else
    echo "Install ${missing[*]} first (for example: sudo apt-get install ${missing[*]})." >&2
    exit 1
  fi
fi

mkdir -p "$dir"
if [ -x "$dir/$name/bin/singular" ] && [ -f "$dir/$name/.verified" ]; then
  echo "Singular is already installed: $dir/$name"
  exit 0
fi
if [ -e "$dir/$name" ]; then
  echo "A folder that was not verified is in $dir/$name. Move it aside and try again." >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for file in "$name.tar.gz" "$onchain.tar.gz" SHA256SUMS; do
  curl -fsSL --retry 3 -o "$tmp/$file" "$base/$file"
done
# both archives must be named in the checksums, and both must match
grep -E " \*?($name|$onchain)\.tar\.gz\$" "$tmp/SHA256SUMS" >"$tmp/wanted"
[ "$(wc -l <"$tmp/wanted")" = 2 ] || {
  echo "SHA256SUMS does not list both $name.tar.gz and $onchain.tar.gz" >&2
  exit 1
}
(cd "$tmp" && sha256sum -c wanted)

tar xzf "$tmp/$name.tar.gz" -C "$dir"
mkdir -p "$tmp/onchain-archive"
tar xzf "$tmp/$onchain.tar.gz" -C "$tmp/onchain-archive"
mkdir -p "$dir/$name/share"
cp "$tmp/onchain-archive/onchain/plutus.json" "$tmp/onchain-archive/onchain/version.txt" "$dir/$name/share/"
touch "$dir/$name/.verified"
echo "Singular is installed: $dir/$name"
