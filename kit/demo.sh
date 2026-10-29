#!/usr/bin/env bash
# Singular v0.18.0: play the same annotated lifecycle as the step-by-step tutorial.
# Carol creates; Alice registers, updates and permanently terminates her key;
# Bob folds, signs bundles and cleans up an expired request. Alice also reclaims.
# Each actor keeps their own vault, settings, journal and receipts.
set -euo pipefail
KIT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PATH="$KIT/bin:$PATH"
export PROCESS_TIME_MS=${PROCESS_TIME_MS:-120000}
export RETRACT_TIME_MS=${RETRACT_TIME_MS:-60000}
case "$PROCESS_TIME_MS$RETRACT_TIME_MS" in *[!0-9]* | '')
  echo "PROCESS_TIME_MS and RETRACT_TIME_MS must be whole numbers of milliseconds." >&2
  exit 2
  ;;
esac
if [ "$PROCESS_TIME_MS" -lt 60000 ]; then
  echo "PROCESS_TIME_MS=$PROCESS_TIME_MS is too short: use 60000 or more." >&2
  exit 2
fi
if [ "$RETRACT_TIME_MS" -lt 30000 ]; then
  echo "RETRACT_TIME_MS=$RETRACT_TIME_MS is too short: use 30000 or more." >&2
  exit 2
fi
WORK=${WORK:-$PWD/singular-demo-run}
mkdir -p "$WORK"
WORK=$(cd "$WORK" && pwd)
# Never replace a previous actor's vault or silently restart an unfinished run.
if [ -e "$WORK/alice/alice.vault" ] || [ -e "$WORK/carol/carol.vault" ]; then
  echo "Choose a fresh WORK folder for a new chain; this folder already has wallets." >&2
  exit 2
fi
umask 077
export blueprint="$KIT/share/plutus.json"
printf 'Singular Demo 1: three actors on a private chain\n'
printf 'Processing window: %s seconds; reclaim window: %s seconds.\n' "$((PROCESS_TIME_MS / 1000))" "$((RETRACT_TIME_MS / 1000))"
printf 'The transcript and each actor\047s receipts stay in %s\n' "$WORK"
# Give this run its chosen windows while leaving the actor run folder empty for setup.
run_tmp=$(mktemp -d)
trap 'rm -rf "$run_tmp"' EXIT
export TMPDIR=$run_tmp
cp -R "$KIT/share/tutorials/demo1" "$run_tmp/tutorial"
chmod -R u+w "$run_tmp/tutorial"
awk -v process="$PROCESS_TIME_MS" -v reclaim="$RETRACT_TIME_MS" '
  /^name = "PROCESS_TIME_MS"/ { value=process }
  /^name = "RETRACT_TIME_MS"/ { value=reclaim }
  /^\[\[path\]\]/ { value="" }
  value != "" && /^default =/ { print "default = \"" value "\""; next }
  value != "" && /^values =/ { print "values = [\"" value "\"]"; next }
  {
    gsub(/PROCESS_TIME_MS = "[0-9]+"/, "PROCESS_TIME_MS = \"" process "\"")
    gsub(/RETRACT_TIME_MS = "[0-9]+"/, "RETRACT_TIME_MS = \"" reclaim "\"")
    sub(/^name = "tutorial"$/, "name = \"script\"")
    print
  }
' "$KIT/share/tutorials/demo1/tutorial.toml" >"$run_tmp/tutorial/tutorial.toml"
if tutorial-stepper play --auto "$run_tmp/tutorial" --path script \
  --run "$WORK" --run-setup --transcript "$WORK/transcript.toml"; then
  bash "$KIT/share/play/check-receipts.sh" "$WORK"
else
  rc=$?
  printf 'The run did not finish (exit status %s). Inspect its transcript and receipts.\n' "$rc" >&2
  if [ -f "$WORK/transcript.toml" ]; then tail -n 60 "$WORK/transcript.toml" >&2; fi
  exit "$rc"
fi
steps=$(sed -n 's/^page = "\(s[0-9][0-9]-[^" ]*\)"$/\1/p' "$WORK/transcript.toml" |
  grep -E '^s(0[1-9]|1[0-6])-' | sort -u | wc -l)
[ "$steps" -eq 16 ] || {
  echo "The transcript does not contain all 16 lifecycle pages." >&2
  exit 1
}
printf 'Lifecycle steps passed: %s/16\n' "$steps"
printf 'All 16 steps passed.\n'
