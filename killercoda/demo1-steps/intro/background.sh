#!/bin/bash
set -x
export DEBIAN_FRONTEND=noninteractive
mkdir -p /root/play
cat > /root/play/install-kit.sh <<'PLAY_EOF'
#!/usr/bin/env bash
# Downloads the Ubuntu kit of a release, checks it against the release's SHA256SUMS and unpacks it.
# Every environment of the play (Killercoda, Codespaces, the tests) installs the kit with this script.
#   install-kit.sh VERSION [DIR]
#     VERSION   the release, for example v0.13.1
#     DIR       where the kit folder goes (default: $HOME)
#   PLAY_KIT_BASE   takes the files from this address instead of the release page; file:///dir tests a kit that is not released yet
set -euo pipefail
version=${1:?usage: install-kit.sh VERSION [DIR]}
dir=${2:-$HOME}
base=${PLAY_KIT_BASE:-https://github.com/lambdasistemi/singular-demo/releases/download/$version}
name=singular-demo-$version-x86_64-linux
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
cat > /root/play/prepare.sh <<'PLAY_EOF'
#!/usr/bin/env bash
# Makes the folders of the play: one directory for Alice and one for Bob, each with the folders for
# their receipts, bundles and witnesses, the settings file they share, and the shell setup every window starts with.
#   prepare.sh KIT_DIR RUN_DIR
set -euo pipefail
kit=$(cd "${1:?usage: prepare.sh KIT_DIR RUN_DIR}" && pwd)
run=${2:?usage: prepare.sh KIT_DIR RUN_DIR}
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$run"/{alice,bob}/{receipts,bundles,witnesses}
run=$(cd "$run" && pwd)
# the settings file Alice's and Bob's windows share; step 1 fills it
[ -f "$run/singular.json" ] || echo '{}' >"$run/singular.json"
printf 'PLAY_KIT=%q\nPLAY_RUN=%q\n' "$kit" "$run" >"$run/play.env"
cp "$here/windows.rc" "$run/windows.rc"
echo "The folders of the play are ready: $run"
PLAY_EOF
cat > /root/play/windows.rc <<'PLAY_EOF'
# What every window of the play starts with: the usual bash setup, the programs, the shared settings
# file, the waiting helper, and one word for each window. prepare.sh copies this file next to play.env.
[ -f ~/.bashrc ] && . ~/.bashrc
. "$(dirname "${BASH_SOURCE[0]}")/play.env"
# an environment that needs more in its windows (the Codespaces tutorial's prompt tracking) names its file here
[ -z "${PLAY_RC_HOOK:-}" ] || . "$PLAY_RC_HOOK"
export PATH="$PLAY_KIT/bin:$PATH"
export blueprint="$PLAY_KIT/share/plutus.json"
export SINGULAR_CONFIG="$PLAY_RUN/singular.json"
# wait_for_slot N: ask the chain for its latest slot every 2 seconds until it is past N (the chain's own clock).
wait_for_slot() {
  local now
  until now=$(curl -fsS "$(jq -r .providerUrl "$PLAY_RUN/devnet.out")/tip" | jq -r '.[0].abs_slot') && [ "$now" -gt "$1" ]; do
    printf '\r  chain slot %s, waiting for slot %s ' "$now" "$1"
    sleep 2
  done
  printf '\n  done: chain slot %s is past slot %s\n' "$now" "$1"
}
# one word goes to a window
alice() { tmux select-window -t alice; }
bob() { tmux select-window -t bob; }
chain() { tmux select-window -t chain; }
PLAY_EOF
cat > /root/play/windows.sh <<'PLAY_EOF'
#!/usr/bin/env bash
# Starts the three windows of the play in one tmux session: 0 alice, 1 bob, 2 chain, each with the shell setup of windows.rc.
#   windows.sh RUN_DIR
#   PLAY_TMUX   the tmux command with its options (default: tmux); an environment with its own tmux server sets it
set -euo pipefail
run=$(cd "${1:?usage: windows.sh RUN_DIR}" && pwd)
t=${PLAY_TMUX:-tmux}
shell="exec bash --rcfile $run/windows.rc -i"
$t new-session -d -s demo -n alice -c "$run/alice" "$shell"
$t new-window -d -t demo -n bob -c "$run/bob" "$shell"
$t new-window -d -t demo -n chain -c "$run" "$shell"
echo "The windows alice, bob and chain are ready."
PLAY_EOF
bash /root/play/install-kit.sh v0.13.1 /root
# tmux holds the three windows
apt-get update -qq && apt-get install -y -qq tmux
tmux -V
bash /root/play/prepare.sh /root/singular-demo-v0.13.1-x86_64-linux /root/singular-demo-run
touch /tmp/finished
