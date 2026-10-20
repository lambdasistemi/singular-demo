#!/usr/bin/env bash
# shellcheck disable=SC2016 # the script run in the container is single-quoted on purpose: its $ expansions happen there
# Runs demo.sh from the kit tarball in a clean Ubuntu container and judges the result.
#   kit/container-run.sh good|short|control-main|control-node|control-window
#     good          the kit as built: demo.sh must exit 0 and show all 16 steps
#     short         the same with the shortest allowed windows (PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000)
#     control-window  windows below the least allowed (59999 and 29999): demo.sh must refuse both with exit 2
#     control-main  the kit with one library of the Haskell programs removed: the run must fail
#                   with the missing-library error (shows the check can fail)
#     control-node  the kit with one library of cardano-node removed: the devnet must fail to start
#   Exit status 0 means the mode behaved as stated above; anything else is a failed check.
# Environment:
#   TARBALL   the kit tarball (required)
#   IMAGE     container image reference (default mirror.gcr.io/library/ubuntu:24.04)
#   OUT       directory for logs and receipts (default ./out); the run of each mode keeps its files in OUT/run-MODE
# The container has no /nix, no host store, no network; only the tarball (read-only) and OUT are mounted.
set -uo pipefail
mode=${1:?good|short|control-main|control-node|control-window}
TARBALL=${TARBALL:?path of the kit tarball}
IMAGE=${IMAGE:-mirror.gcr.io/library/ubuntu:24.04}
OUT=${OUT:-$PWD/out}
mkdir -p "$OUT"
OUT=$(readlink -f "$OUT")
TARBALL=$(readlink -f "$TARBALL")
tarball=$(basename "$TARBALL")
kit=${tarball%.tar.gz}
log=$OUT/container-run-$mode.log
inner='
set -u
echo "== /etc/os-release"; cat /etc/os-release
echo "== uname"; uname -srm
echo "== user"; id
echo "== is there a /nix in this container?"
if [ -e /nix ]; then echo "YES: /nix exists"; ls -la /nix; else echo "no: test -e /nix fails; ls says:"; ls -ld /nix 2>&1; fi
echo "== tools the host image lacks"
for t in jq curl nix patchelf; do if command -v $t >/dev/null; then echo "$t: present at $(command -v $t)"; else echo "$t: absent"; fi; done
echo "== unpack"
cd /work && tar xzf /dist/$TARBALL && cd $KIT && cat VERSION
'
case "$mode" in
  good) inner+='export WORK=/out/singular-demo-run
' ;;
  short) inner+='export WORK=/out/singular-demo-run PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000
' ;;
  control-window) inner+='for v in PROCESS_TIME_MS=59999 RETRACT_TIME_MS=29999; do
  echo "== $v ./demo.sh"; env $v ./demo.sh; echo "WINDOWCHECK $v exit=$?"
done
' ;;
  control-main) inner+='echo "== BREAK THE KIT: delete lib/main/libsecp256k1.so.2"; rm -v lib/main/libsecp256k1.so.2
' ;;
  control-node) inner+='echo "== BREAK THE KIT: delete lib/node/liblmdb.so (a library of cardano-node only)"; rm -v lib/node/liblmdb.so
' ;;
  *)
    echo "unknown mode $mode" >&2
    exit 2
    ;;
esac
if [ "$mode" = control-window ]; then
  inner+='rc=0
'
else
  inner+='echo "== run demo.sh"; date -u +%FT%TZ
./demo.sh; rc=$?
date -u +%FT%TZ; echo "== demo.sh exit status: $rc"
'
fi
case "$mode" in
  good | short) inner+='
if [ $rc = 0 ]; then
  echo "== transaction tools on the demo'"'"'s own bundles"
  export PATH=$PWD/bin:$PATH
  first=$(ls -tr /out/singular-demo-run/bundles/*.bundle | sed -n 1p); second=$(ls -tr /out/singular-demo-run/bundles/*.bundle | sed -n 2p)
  echo "first bundle: $first"; echo "second bundle: $second"
  jq ".transactions[0].envelope" "$first" > /out/first.envelope
  jq ".transactions[0].envelope" "$second" > /out/second.envelope
  tx-inspect /out/first.envelope > /out/tx-inspect.txt; echo "TXTOOLS inspect-exit=$?"
  echo "TXTOOLS fee-lines=$(grep -ci fee /out/tx-inspect.txt)"; grep -i fee /out/tx-inspect.txt
  tx-diff /out/first.envelope /out/first.envelope > /out/tx-diff-same.txt; echo "TXTOOLS diff-same-exit=$?"
  tx-diff /out/first.envelope /out/second.envelope > /out/tx-diff.txt; echo "TXTOOLS diff-different-exit=$?"
  echo "TXTOOLS diff-different-A-lines=$(grep -c "A: " /out/tx-diff.txt) B-lines=$(grep -c "B: " /out/tx-diff.txt)"
fi
' ;;
esac
inner+='echo "== anything left running?"
n=0; for p in /proc/[0-9]*; do e=$(readlink $p/exe 2>/dev/null); case "$e" in /work/*) echo "LEFT: pid ${p#/proc/} $e"; n=$((n+1));; esac; done; echo "kit processes still running: $n"
echo "(scan done)"
# the demo keeps its folders private (700); the host user that uploads the evidence is another uid
chmod -R a+rX /out 2>/dev/null
exit $rc
'
rm -rf "$OUT/run-$mode"
mkdir -m 777 "$OUT/run-$mode"
{
  echo "# container-run.sh $mode  $(date -u +%FT%TZ)  image $IMAGE"
  docker run --rm --memory 8g --network none --user 1000:1000 --tmpfs /work:rw,exec,mode=1777 \
    -e "TARBALL=$tarball" -e "KIT=$kit" \
    -v "$(dirname "$TARBALL"):/dist:ro" -v "$OUT/run-$mode:/out" "$IMAGE" bash -c "$inner"
  echo "== docker run exit status: $?"
} >"$log" 2>&1

rc=$(sed -n 's/^== demo.sh exit status: //p' "$log")
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
failed() { [ -n "${rc:-}" ] && [ "$rc" != 0 ]; }
echo "container-run $mode: demo.sh exit status ${rc:-none}; log $log"
case "$mode" in
  good | short)
    steps=$(grep -c '^━━ Step [0-9]* of 16 ' "$log")
    expect "demo.sh exit status 0" [ "${rc:-}" = 0 ]
    expect "16 steps shown (counted $steps)" [ "$steps" = 16 ]
    expect "'All 16 steps passed.' printed" has '^All 16 steps passed\.'
    expect "/nix absent in the container" has '^no: test -e /nix fails'
    expect "no kit process left running" has '^kit processes still running: 0$'
    expect "tx-inspect exit 0" has '^TXTOOLS inspect-exit=0$'
    expect "tx-inspect output has a fee line" has '^TXTOOLS fee-lines=[1-9]'
    expect "tx-diff of a transaction against itself exit 0" has '^TXTOOLS diff-same-exit=0$'
    # tx-diff exits 1 when the two transactions differ (an error exits 1 too, but prints no A:/B: lines)
    expect "tx-diff of two different transactions: exit 1" has '^TXTOOLS diff-different-exit=1$'
    expect "tx-diff of two different transactions: A: and B: lines" has '^TXTOOLS diff-different-A-lines=[1-9][0-9]* B-lines=[1-9]'
    # measured time of the run, from the two timestamps the container prints around demo.sh
    t0=$(grep -A1 '^== run demo.sh$' "$log" | tail -1)
    t1=$(grep -B1 '^== demo.sh exit status' "$log" | head -1)
    echo "  time  demo.sh took $(($(date -u -d "$t1" +%s) - $(date -u -d "$t0" +%s))) s"
    ;;
  control-window)
    expect "PROCESS_TIME_MS=59999 refused with exit 2" has '^WINDOWCHECK PROCESS_TIME_MS=59999 exit=2$'
    expect "PROCESS_TIME_MS refusal says why" has 'PROCESS_TIME_MS=59999 is too short'
    expect "RETRACT_TIME_MS=29999 refused with exit 2" has '^WINDOWCHECK RETRACT_TIME_MS=29999 exit=2$'
    expect "RETRACT_TIME_MS refusal says why" has 'RETRACT_TIME_MS=29999 is too short'
    ;;
  control-main)
    expect "demo.sh failed (status ${rc:-none})" failed
    expect "missing-library error named" has 'error while loading shared libraries: libsecp256k1.so.2'
    ;;
  control-node)
    expect "demo.sh failed (status ${rc:-none})" failed
    expect "devnet failure named" has 'the devnet exited before it was ready'
    ;;
esac
[ "$ok" = 1 ]
