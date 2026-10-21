#!/usr/bin/env bash
# shellcheck disable=SC2016 # the script run in the container is single-quoted on purpose: its $ expansions happen there
# Plays the tutorial with the kit's drive.sh in a clean Ubuntu container with no tmux, no Nix and no network, so the
# page and the windows run on the kit's own tmux. The page types every command and turns every page by itself
# (DRIVE_AUTO=yes); then the receipts of Alice and Bob are judged and the screens of the windows are kept.
#   TARBALL=dist/KIT.tar.gz kit/drive-run.sh
# Environment:
#   TARBALL   the kit tarball (required)
#   IMAGE     container image reference (default mirror.gcr.io/library/ubuntu:24.04)
#   OUT       directory for the log, the run's folder and the screens (default ./out)
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
TARBALL=$(readlink -f "${TARBALL:?path of the kit tarball}")
IMAGE=${IMAGE:-mirror.gcr.io/library/ubuntu:24.04}
OUT=${OUT:-$PWD/out}
mkdir -p "$OUT"
OUT=$(readlink -f "$OUT")
tarball=$(basename "$TARBALL")
log=$OUT/drive-run.log
inner='
set -u
echo "== is there a tmux in this container?"
if command -v tmux; then echo "YES: the run would not show that the kit brings its own"; exit 1; fi
echo "no"
cd /work && tar xzf "/dist/$TARBALL" && cd "${TARBALL%.tar.gz}" && cat VERSION
echo "== drive.sh"; date -u +%FT%TZ
WORK=/out/run DRIVE_AUTO=yes ./drive.sh; echo "DRIVE exit=$?"
t="bin/tmux -L singular-demo"
pages=$(bin/jq "(.details.steps | length) + 1" share/scenario/index.json)
state=/out/run/.drive
# the page writes the page it is on, and closes its pane after the last one; up to 40 minutes
for i in $(seq 1 1200); do
  pane=$(cat $state/page-pane 2>/dev/null)
  [ "$(cat $state/page 2>/dev/null)" = "$pages" ] && [ -n "$pane" ] && ! $t list-panes -a -F "#{pane_id}" | grep -qx "$pane" && break
  sleep 2
done
date -u +%FT%TZ
echo "PAGES reached=$(cat $state/page 2>/dev/null) of=$pages"
echo "== the chain, after the last page stopped it with kill %1"
# devnet and cardano-node run through the loader the kit brings, lib/*/ld-linux-x86-64.so.2
n=0; for p in /proc/[0-9]*; do case "$(readlink $p/exe 2>/dev/null)" in /work/*/lib/*/ld-linux*) echo "LEFT: pid ${p#/proc/} $(tr "\0" " " <$p/cmdline | cut -c1-80)"; n=$((n+1));; esac; done
echo "CHAIN processes=$n"
for w in alice bob chain; do $t capture-pane -p -J -S - -t demo:$w >/out/window-$w.log; done
$t kill-server
echo "== receipts"
PATH=$PWD/bin:$PATH bash /check-receipts.sh /out/run; echo "RECEIPTS exit=$?"
echo "== error lines on the screens"
grep -nE "jq: error|command not found|curl: [(]|No such file or directory|Uncaught exception|integer expression expected" /out/window-*.log
echo "ERRORS lines=$(cat /out/window-*.log | grep -cE "jq: error|command not found|curl: [(]|No such file or directory|Uncaught exception|integer expression expected")"
# the demo keeps its folders private (700); the host user that uploads the evidence is another uid
chmod -R a+rX /out 2>/dev/null
'
rm -rf "$OUT/run-drive"
mkdir -m 777 "$OUT/run-drive"
{
  echo "# drive-run.sh  $(date -u +%FT%TZ)  image $IMAGE"
  docker run --rm --memory 8g --network none --user 1000:1000 --tmpfs /work:rw,exec,mode=1777 \
    -e "TARBALL=$tarball" -e HOME=/work \
    -v "$(dirname "$TARBALL"):/dist:ro" -v "$here/../demos/demo1/play/check-receipts.sh:/check-receipts.sh:ro" \
    -v "$OUT/run-drive:/out" "$IMAGE" bash -c "$inner"
  echo "== docker run exit status: $?"
} >"$log" 2>&1

ok=1
expect() { # description, then the command that must succeed
  local what=$1
  shift
  if "$@"; then echo "  ok    $what"; else
    echo "  FAIL  $what"
    ok=0
  fi
}
has() { grep -q -- "$1" "$log"; }
echo "drive-run: log $log"
expect "no tmux in the image: the kit's own runs the windows" has '^no$'
expect "drive.sh started the windows and the page (exit 0)" has '^DRIVE exit=0$'
expect "the page went through every page and closed" grep -qE '^PAGES reached=([0-9]+) of=\1$' "$log"
expect "the last page stopped the chain" has '^CHAIN processes=0$'
expect "every receipt holds" has '^RECEIPTS exit=0$'
expect "no error line on the screens of the windows" has '^ERRORS lines=0$'
t0=$(grep -A1 '^== drive.sh$' "$log" | tail -1)
t1=$(grep -B1 '^PAGES reached=' "$log" | head -1)
echo "  time  the page took $(($(date -u -d "$t1" +%s) - $(date -u -d "$t0" +%s))) s"
[ "$ok" = 1 ]
