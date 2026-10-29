#!/usr/bin/env bash
# Drives demo.sh in pause mode through a terminal, as a reader would: it answers the mode question with p, and at
# each "Press Enter to run step N" prompt it waits HOLD seconds, checks that no file of the actors changed while it
# waited (the step did not start before Enter), then presses Enter.
#   pause-drive.sh KIT_DIR WORK LOG
#   HOLD     seconds to wait at each prompt (default 3)
#   LONG     a step number held for LONG_HOLD seconds instead (default 9; 120 s), a pause longer than a window
# Prints one line per prompt (PAUSE held step N, or PAUSE moved step N), then PAUSE prompts=N and PAUSE exit=STATUS.
# Needs script (util-linux), which gives demo.sh a terminal.
set -uo pipefail
kit=$(cd "${1:?usage: pause-drive.sh KIT_DIR WORK LOG}" && pwd)
work=${2:?usage: pause-drive.sh KIT_DIR WORK LOG}
log=${3:?usage: pause-drive.sh KIT_DIR WORK LOG}
hold=${HOLD:-3}
long=${LONG:-9}
long_hold=${LONG_HOLD:-120}
input=$(mktemp -u)
mkfifo "$input"
: >"$log"
(
  cd "$kit" && env -u DEMO_MODE WORK="$work" script -qfec ./demo.sh /dev/null <"$input" >>"$log" 2>&1
  echo "PAUSE exit=$?" >>"$log"
) &
exec 3>"$input"
ended() { grep -q '^PAUSE exit=' "$log"; }
# the files the actors write: settings, receipts, bundles and witnesses (not the journals, not the chain's log)
actors() { find "$work"/alice "$work"/bob "$work"/carol -type f -not -path '*-journal/*' -printf '%p %s %T@\n' 2>/dev/null | sort; }
until grep -q 'pause before each step?' "$log"; do
  ended && break
  sleep 0.5
done
printf 'p\n' >&3
prompts=0
while :; do
  until [ "$(grep -o 'Press Enter to run step [0-9]*' "$log" | wc -l)" -gt "$prompts" ]; do
    ended && break 2
    sleep 0.5
  done
  prompts=$((prompts + 1))
  step=$(grep -o 'Press Enter to run step [0-9]*' "$log" | tail -1 | awk '{print $NF}')
  before=$(actors)
  if [ "$step" = "$long" ]; then sleep "$long_hold"; else sleep "$hold"; fi
  if [ "$(actors)" = "$before" ]; then echo "PAUSE held step $step"; else echo "PAUSE moved step $step"; fi
  printf '\n' >&3
done
exec 3>&-
wait
rm -f "$input"
echo "PAUSE prompts=$prompts"
sed -n 's/^PAUSE exit=/PAUSE exit=/p' "$log" | tail -1
