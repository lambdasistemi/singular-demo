#!/usr/bin/env bash
# shellcheck disable=SC2016 # the script run in the container is single-quoted on purpose: its $ expansions happen there
# Plays a tutorial with the kit's drive.sh in a clean Ubuntu container with no tmux, no node, no Nix and no network, so
# the page, the windows and the tools run on the kit's own tmux and node. The page types every command and turns every
# page by itself (DRIVE_AUTO=yes); then what the people wrote is judged and the screens of the windows are kept.
#   TARBALL=dist/KIT.tar.gz kit/drive-run.sh                        Demo 1: the receipts of Alice and Bob
#   SCENARIO=pay-by-name TARBALL=dist/KIT.tar.gz kit/drive-run.sh   the pay-by-name story: the files of its five people
# Environment:
#   TARBALL   the kit tarball (required)
#   SCENARIO  demo1 (default) or pay-by-name
#   IMAGE     container image reference (default mirror.gcr.io/library/ubuntu:24.04)
#   OUT       directory for the log, the run's folder and the screens (default ./out)
#   PROCESS_TIME_MS, RETRACT_TIME_MS   the registry's windows for the run, passed to drive.sh (default: the tutorial's)
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
TARBALL=$(readlink -f "${TARBALL:?path of the kit tarball}")
IMAGE=${IMAGE:-mirror.gcr.io/library/ubuntu:24.04}
OUT=${OUT:-$PWD/out}
mkdir -p "$OUT"
OUT=$(readlink -f "$OUT")
tarball=$(basename "$TARBALL")
SCENARIO=${SCENARIO:-demo1}
case $SCENARIO in
  demo1)
    DRIVE_ARG=
    SOCKET=singular-demo
    SCEN_INDEX=share/scenario/index.json
    WINDOWS="alice bob chain"
    CHECK=$here/../demos/demo1/play/check-receipts.sh
    log=$OUT/drive-run.log
    rundir=$OUT/run-drive
    ;;
  pay-by-name)
    DRIVE_ARG=pay-by-name
    SOCKET=singular-pay-by-name
    SCEN_INDEX=share/pay-by-name/scenario/index.json
    WINDOWS="carol alice dave bob chain"
    CHECK=$here/../demos/pay-by-name/check-run.sh
    log=$OUT/drive-run-pay-by-name.log
    rundir=$OUT/run-drive-pay-by-name
    ;;
  *)
    echo "SCENARIO is demo1 or pay-by-name" >&2
    exit 2
    ;;
esac
inner='
set -u
echo "== is there a tmux in this container?"
if command -v tmux; then echo "YES: the run would not show that the kit brings its own"; exit 1; fi
echo "no"
echo "== is there a node in this container?"
if command -v node; then echo "YES: the run would not show that the kit brings its own"; exit 1; fi
echo "no"
cd /work && tar xzf "/dist/$TARBALL" && cd "${TARBALL%.tar.gz}" && cat VERSION
echo "== drive.sh"; date -u +%FT%TZ
WORK=/out/run DRIVE_AUTO=yes ./drive.sh $DRIVE_ARG; echo "DRIVE exit=$?"
t="bin/tmux -L $SOCKET"
pages=$(bin/jq "(.details.steps | length) + 1" $SCEN_INDEX)
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
for w in $WINDOWS; do $t capture-pane -p -J -S - -t demo:$w >/out/window-$w.log; done
$t kill-server
echo "== receipts"
PATH=$PWD/bin:$PATH bash /check-run.sh /out/run /out; echo "RECEIPTS exit=$?"
echo "== error lines on the screens"
grep -nE "jq: error|command not found|curl: [(]|No such file or directory|Uncaught exception|integer expression expected" /out/window-*.log
echo "ERRORS lines=$(cat /out/window-*.log | grep -cE "jq: error|command not found|curl: [(]|No such file or directory|Uncaught exception|integer expression expected")"
# the demo keeps its folders private (700); the host user that uploads the evidence is another uid
chmod -R a+rX /out 2>/dev/null
'
rm -rf "$rundir"
mkdir -m 777 "$rundir"
{
  echo "# drive-run.sh  $(date -u +%FT%TZ)  image $IMAGE"
  docker run --rm --memory 8g --network none --user 1000:1000 --tmpfs /work:rw,exec,mode=1777 \
    -e "TARBALL=$tarball" -e HOME=/work -e PROCESS_TIME_MS -e RETRACT_TIME_MS \
    -e "DRIVE_ARG=$DRIVE_ARG" -e "SOCKET=$SOCKET" -e "SCEN_INDEX=$SCEN_INDEX" -e "WINDOWS=$WINDOWS" \
    -v "$(dirname "$TARBALL"):/dist:ro" -v "$CHECK:/check-run.sh:ro" \
    -v "$rundir:/out" "$IMAGE" bash -c "$inner"
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
expect "no tmux and no node in the image: the kit's own run the windows and the tools" test "$(grep -c '^no$' "$log")" -ge 2
expect "drive.sh started the windows and the page (exit 0)" has '^DRIVE exit=0$'
expect "the page went through every page and closed" grep -qE '^PAGES reached=([0-9]+) of=\1$' "$log"
expect "the last page stopped the chain" has '^CHAIN processes=0$'
expect "every receipt holds" has '^RECEIPTS exit=0$'
expect "no error line on the screens of the windows" has '^ERRORS lines=0$'
t0=$(grep -A1 '^== drive.sh$' "$log" | tail -1)
t1=$(grep -B1 '^PAGES reached=' "$log" | head -1)
echo "  time  the page took $(($(date -u -d "$t1" +%s) - $(date -u -d "$t0" +%s))) s"
[ "$ok" = 1 ]
