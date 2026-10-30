#!/usr/bin/env bash
# Singular v0.19.0: play the same annotated lifecycle as the step-by-step tutorial.
# Carol creates; Alice registers, updates and permanently terminates her key;
# Bob folds whatever is pending, signs bundles and cleans up an expired request. Alice also reclaims.
# After each change of the key, Alice or Bob reads it back from the chain.
# Each actor keeps their own vault, settings, journal and receipts.
# Two modes: continuous runs every step straight through; pause says what each step
# will do and waits for Enter before running it. DEMO_MODE=continuous|pause chooses
# without the question; with no terminal on standard input the mode is continuous.
set -euo pipefail
KIT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PATH="$KIT/bin:$PATH"
# The steps that follow a booking run without a pause: a booking is folded before its processing deadline.
unpaused="04 13 16"
mode=${DEMO_MODE:-}
if [ -z "$mode" ]; then
  if [ -t 0 ]; then
    printf 'Run straight through, or pause before each step? [c]ontinuous or [p]ause (default c): '
    read -r answer || answer=""
    case "$answer" in
      "" | c | C | continuous) mode=continuous ;;
      p | P | pause) mode=pause ;;
      *)
        echo "Answer c or p." >&2
        exit 2
        ;;
    esac
  else
    mode=continuous
  fi
fi
case "$mode" in continuous | pause) ;; *)
  echo "DEMO_MODE=$mode: use continuous or pause." >&2
  exit 2
  ;;
esac
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
printf 'Mode: %s\n' "$mode"
printf 'Processing window: %s seconds; reclaim window: %s seconds.\n' "$((PROCESS_TIME_MS / 1000))" "$((RETRACT_TIME_MS / 1000))"
printf 'The transcript and each actor\047s receipts stay in %s\n' "$WORK"
# Give this run its chosen windows while leaving the actor run folder empty for setup.
run_tmp=$(mktemp -d)
prompts=""
trap 'if [ -n "$prompts" ]; then kill "$prompts" 2>/dev/null || true; fi; rm -rf "$run_tmp"' EXIT
# The stepper's standard input: the terminal in continuous mode, nothing in pause mode.
exec 3<&0
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

# Pause mode: each step page of the copy starts with a block that waits for a file of this run; the prompts
# below say what the step does, wait for Enter and write that file.
step_page() { find "$run_tmp/tutorial" -maxdepth 1 -name "s$1-*.md" | head -1; }
step_title() { sed -n '1s/^# *//p' "$1"; }
step_summary() { awk 'NR > 1 && /^[^`*#]/ && NF { print; exit }' "$1"; }
pause_prompts() {
  local n page next input=yes
  for n in $(seq -w 1 16); do
    case " $unpaused " in *" $n "*) continue ;; esac
    until [ -e "$gate/want-$n" ]; do sleep 0.2; done
    page=$(step_page "$n")
    printf '\n%s\n%s\n' "$(step_title "$page")" "$(step_summary "$page")"
    next=$(printf '%02d' $((10#$n + 1)))
    case " $unpaused " in *" $next "*)
      printf 'Then %s, without a pause: a booking is folded before its processing deadline.\n' "$(step_title "$(step_page "$next")" | sed 's/^Step [0-9]*: //')"
      ;;
    esac
    if [ "$input" = yes ]; then
      printf 'Press Enter to run step %d. ' "$((10#$n))"
      if ! read -r _; then
        input=no
        printf '\nNo more input: the remaining steps run without a pause.\n'
      fi
    fi
    : >"$gate/go-$n"
  done
}
if [ "$mode" = pause ]; then
  gate=$run_tmp/gate
  mkdir "$gate"
  for n in $(seq -w 1 16); do
    case " $unpaused " in *" $n "*) continue ;; esac
    page=$(step_page "$n")
    window=$(sed -n 's/^```bash {.*window=\([A-Za-z0-9]*\).*}$/\1/p' "$page" | head -1)
    awk -v w="$window" -v g="$gate" -v n="$n" '
      !done && /^```bash \{/ { print "```bash { window=" w " }"; print ": >" g "/want-" n "; until [ -e " g "/go-" n " ]; do sleep 0.2; done"; print "```"; print ""; done=1 }
      { print }' "$page" >"$page.new"
    mv "$page.new" "$page"
  done
  printf 'Steps 4, 13 and 16 run without a pause, because a booking must be folded before its processing deadline.\n'
  printf 'Ctrl+C stops the run.\n'
  printf 'Starting the private chain and the three wallets.\n'
  pause_prompts 0<&3 &
  prompts=$!
  # the stepper reads nothing: the Enter presses are for the prompts
  exec 3</dev/null
fi

if tutorial-stepper play --auto "$run_tmp/tutorial" --path script \
  --run "$WORK" --run-setup --transcript "$WORK/transcript.toml" <&3; then
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
