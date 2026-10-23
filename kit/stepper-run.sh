#!/usr/bin/env bash
# shellcheck disable=SC2016 # the script run in the container is single-quoted on purpose: its $ expansions happen there
# Plays a carried tutorial with the kit's tutorial-stepper in a clean Ubuntu container with no tmux, no node, no Nix
# and no network, so the windows and the tools run on the kit's own tmux and programs. The stepper plays the tested
# path unattended (--auto); then what the people wrote is judged with the tutorial's receipt checks.
#   TARBALL=dist/KIT.tar.gz kit/stepper-run.sh                        Demo 1's shortest path: receipts of Alice and Bob
#   SCENARIO=pay-by-name TARBALL=dist/KIT.tar.gz kit/stepper-run.sh   the pay-by-name story: the files of its five people
# Environment:
#   TARBALL   the kit tarball (required)
#   SCENARIO  demo1 (default) or pay-by-name
#   IMAGE     container image reference (default mirror.gcr.io/library/ubuntu:24.04)
#   OUT       directory for the log, the run's folder and the transcript (default ./out)
#   PROCESS_TIME_MS, RETRACT_TIME_MS   the registry's windows (default: the tutorial's tested path;
#                                      Demo 1's short path plays 60000 and 30000)
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
    TUTORIAL=share/tutorials/demo1
    PATH_ARG="--path short"
    CHECK=$here/../demos/demo1/play/check-receipts.sh
    log=$OUT/stepper-run.log
    rundir=$OUT/run-stepper
    ;;
  pay-by-name)
    TUTORIAL=share/tutorials/pay-by-name
    PATH_ARG=
    CHECK=$here/../demos/pay-by-name/check-run.sh
    log=$OUT/stepper-run-pay-by-name.log
    rundir=$OUT/run-stepper-pay-by-name
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
echo "== tutorial-stepper check"; date -u +%FT%TZ
export PATH=$PWD/bin:$PATH
bin/tutorial-stepper --version
bin/tutorial-stepper check "$TUTORIAL"
echo "== tutorial-stepper play --auto"; date -u +%FT%TZ
# shellcheck disable=SC2086 # PATH_ARG is --path short or empty, split on purpose
bin/tutorial-stepper play --auto "$TUTORIAL" $PATH_ARG --run /out/run --run-setup --transcript /out/transcript.toml; echo "STEPPER exit=$?"
date -u +%FT%TZ
echo "== the chain, after the run removed its server"
# devnet and cardano-node run through the loader the kit brings, lib/*/ld-linux-x86-64.so.2. Unlike drive.sh,
# the tutorial has no stop step: after the last page the windows (and the chain) stay for the learner to
# inspect, so leftovers are reported, not refused. The container takes them with it when it exits.
leftover=0; for p in /proc/[0-9]*; do case "$(readlink $p/exe 2>/dev/null)" in /work/*/lib/*/ld-linux*) echo "LEFT: pid ${p#/proc/} $(tr "\0" " " <$p/cmdline | cut -c1-80)"; leftover=$((leftover+1));; esac; done
echo "CHAIN processes=$leftover"
echo "== receipts"
bash /check-run.sh /out/run; echo "RECEIPTS exit=$?"
echo "== transcript commands"
grep -c "^\[\[command\]\]" /out/transcript.toml
# the demo keeps its folders private (700); the host user that uploads the evidence is another uid
chmod -R a+rX /out 2>/dev/null
'
rm -rf "$rundir"
mkdir -m 777 "$rundir"
{
  echo "# stepper-run.sh  $(date -u +%FT%TZ)  image $IMAGE"
  docker run --rm --memory 8g --network none --user 1000:1000 --tmpfs /work:rw,exec,mode=1777 \
    -e "TARBALL=$tarball" -e HOME=/work -e PROCESS_TIME_MS -e RETRACT_TIME_MS \
    -e "TUTORIAL=$TUTORIAL" -e "PATH_ARG=$PATH_ARG" \
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
echo "stepper-run $SCENARIO: log $log"
expect "no tmux and no node in the image: the kit's own run the windows" test "$(grep -c '^no$' "$log")" -ge 2
expect "the carried tutorial checks" grep -qE '^[0-9]+ pages?, [0-9]+ commands$' "$log"
expect "the stepper played the path (exit 0)" has '^STEPPER exit=0$'
expect "every receipt holds" has '^RECEIPTS exit=0$'
t0=$(grep -A1 '^== tutorial-stepper play --auto$' "$log" | tail -1)
t1=$(grep -B1 '^== the chain' "$log" | head -1)
echo "  time  the stepper took $(($(date -u -d "$t1" +%s) - $(date -u -d "$t0" +%s))) s"
echo "  transcript commands: $(grep -c '^\[\[command\]\]' "$rundir/transcript.toml")"
[ "$ok" = 1 ]
