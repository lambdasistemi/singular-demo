#!/bin/bash
set -x
mkdir -p /root/play
apt-get update -qq && apt-get install -y -qq passwd util-linux
id singular-demo >/dev/null 2>&1 || useradd --create-home --shell /bin/bash singular-demo
cat > /root/play/install-kit.sh <<'PLAY_EOF'
#!/usr/bin/env bash
# Downloads the Ubuntu kit of a release, checks it against the release's SHA256SUMS and unpacks it.
# Every environment of the play (Killercoda, Codespaces, the tests) installs the kit with this script.
#   install-kit.sh RELEASE [DIR]
#     RELEASE   the kit's release: the Singular release and the kit's revision, for example v0.16.0-1
#     DIR       where the kit folder goes (default: $HOME)
#   PLAY_KIT_BASE   takes the files from this address instead of the release page; file:///dir tests a kit that is not released yet
set -euo pipefail
release=${1:?usage: install-kit.sh RELEASE [DIR]}
dir=${2:-$HOME}
base=${PLAY_KIT_BASE:-https://github.com/lambdasistemi/singular-demo/releases/download/$release}
name=singular-demo-$release-x86_64-linux
mkdir -p "$dir"
if [ -x "$dir/$name/bin/singular" ] && [ -f "$dir/$name/.verified" ]; then
  echo "The kit is already installed: $dir/$name"
  exit 0
fi
if [ -e "$dir/$name" ]; then
  echo "A kit that was not verified is in $dir/$name. Move it aside and try again." >&2
  exit 1
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL --retry 3 -o "$tmp/$name.tar.gz" "$base/$name.tar.gz"
curl -fsSL --retry 3 -o "$tmp/SHA256SUMS" "$base/SHA256SUMS"
(cd "$tmp" && sha256sum -c SHA256SUMS)
tar xzf "$tmp/$name.tar.gz" -C "$dir"
touch "$dir/$name/.verified"
echo "The kit is installed: $dir/$name"
PLAY_EOF
bash /root/play/install-kit.sh v0.18.0-1 /home/singular-demo
chown -R singular-demo:singular-demo /home/singular-demo/singular-demo-v0.18.0-1-x86_64-linux
touch /tmp/finished
