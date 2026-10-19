#!/usr/bin/env bash
# Runs a generated Killercoda scenario the way Killercoda runs it, on a clean Ubuntu with no Nix, in REAL tmux windows:
#   node runbook/killercoda.js /tmp/scenario
#   docker run --rm --memory 8g -v /tmp/scenario:/scenario:ro -v "$PWD":/repo:ro ubuntu:24.04 \
#     bash /repo/runbook/scenario-test.sh /scenario
# 1. the machine gets curl (Killercoda's has it) and the scenario's intro/background.sh runs: kit, tmux, env.sh
# 2. the click-to-run blocks of every step, in the order of index.json, then of the finish page, are TYPED into the
#    tmux window the learner is in (the switchers move that window), each followed by waiting for the shell's prompt;
#    passphrase prompts are answered when they appear on the screen, as a person would
# 3. the receipts of Alice's and Bob's directories are checked
set -u
scenario=$(cd "${1:?usage: scenario-test.sh SCENARIO_DIR}" && pwd)
here=$(cd "$(dirname "$0")" && pwd)
bash "$here/lint.sh" "$scenario"/*/text.md || exit 1
export HOME=/root TERM=xterm-256color
cd "$HOME"
if ! command -v curl >/dev/null; then apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null; fi
work=$(mktemp -d /tmp/sc-XXXXXX)
if ! bash "$scenario/intro/background.sh" > "$work/background.log" 2>&1 || [ ! -f /tmp/finished ]; then
  echo "FAIL  intro/background.sh did not finish"; tail -8 "$work/background.log"; exit 1
fi
echo "ok    intro/background.sh finished"
# no kit on the PATH here on purpose: as on Killercoda, the tmux server starts from a plain shell without it
tmux start-server \; set -g exit-empty off \; set -g default-size 200x50

# ---- the blocks, one file each
pages=$(grep -o '"text": *"[^"]*"' "$scenario/index.json" | cut -d'"' -f4)
n=0
for p in $pages; do
  awk -v dir="$work" -v start="$n" '
    /^```bash$/ {inb=1; buf=""; next}
    inb && /^```\{\{exec\}\}$/ {start++; f=sprintf("%s/blk-%04d", dir, start); printf "%s", buf > f; close(f); inb=0; next}
    inb && /^```$/ {inb=0; next}
    inb {buf = buf $0 "\n"}
    END {print start > (dir "/.last")}' "$scenario/$p"
  n=$(cat "$work/.last")
done
echo "ok    $n click-to-run blocks from $(echo "$pages" | wc -l) pages"

# ---- the terminal
declare -A started
current=""          # the tmux window the learner is in; empty before "tmux attach"
passwords_alice="alice"; passwords_bob="bob"

tx() { tmux send-keys -t "demo:$1" -l -- "$2"; tmux send-keys -t "demo:$1" Enter; }

init_window() {  # the shell of a window reports each prompt it shows, so the driver knows when a command is over
  local w=$1
  [ -n "${started[$w]:-}" ] && return
  : > "/tmp/prompts-$w"
  tx "$w" "PS1='\$ '; PROMPT_COMMAND='echo p >> /tmp/prompts-$w'"
  local i; for i in $(seq 1 100); do [ -s "/tmp/prompts-$w" ] && break; sleep 0.2; done
  started[$w]=1
}

ERROR_LINES='jq: error|command not found|curl: [(]|No such file or directory|Uncaught exception|integer expression expected'
run_block() {
  local file=$1 w=$current
  local expected; expected=$(awk 'NF && $0 !~ /\\$/ {c++} END {print c+0}' "$file")
  init_window "$w"
  local base; base=$(wc -l < "/tmp/prompts-$w")
  local hist0; hist0=$(tmux capture-pane -p -J -S - -t "demo:$w" | grep -c .)
  local line
  while IFS= read -r line; do tx "$w" "$line"; done < "$file"
  local answered=-1 waited=0
  while :; do
    local have; have=$(wc -l < "/tmp/prompts-$w")
    [ "$have" -ge $((base + expected)) ] && break
    # one snapshot of the screen: the last line and the line count must come from the same moment, or a shell prompt
    # that appears in between makes the last passphrase prompt look new, and the answer is typed into the shell
    local snap; snap=$(tmux capture-pane -p -J -t "demo:$w" | grep .)
    if printf '%s\n' "$snap" | tail -1 | grep -qi 'passphrase: *$'; then
      local c; c=$(printf '%s\n' "$snap" | wc -l)
      if [ "$c" -gt "$answered" ]; then
        local pw="passwords_$w"; tx "$w" "${!pw}"; answered=$c
      fi
    fi
    sleep 0.4; waited=$((waited + 1))
    if [ "$waited" -gt 3000 ]; then echo "FAIL  block timed out in window $w:"; cat "$file"; echo "--- screen:"; tmux capture-pane -p -t "demo:$w" | grep . | tail -8; return 1; fi
  done
  # what this block printed must hold no error line (a missing file, a failed jq, a missing command)
  local bad; bad=$(tmux capture-pane -p -J -S - -t "demo:$w" | grep . | tail -n +$((hist0 + 1)) | grep -E "$ERROR_LINES" | head -3)
  if [ -n "$bad" ]; then echo "FAIL  error line on the screen of window $w after this block:"; cat "$file"; echo "--- error lines:"; echo "$bad"; return 1; fi
}

dump_windows() { local w; for w in alice bob devnet; do echo "=== window $w:"; tmux capture-pane -p -S - -t "demo:$w" 2>/dev/null | grep . | tail -"${DUMP_LINES:-60}"; done; }

for i in $(seq 1 "$n"); do
  f=$(printf '%s/blk-%04d' "$work" "$i")
  first=$(head -1 "$f")
  case "$first" in
    "tmux attach -t demo"*) current=alice; echo "ok    attached; the learner is in the window alice"; continue;;
  esac
  if [ -z "$current" ]; then
    # before tmux attach the learner is in the plain shell
    bash "$f" > "$work/plain-$i.log" 2>&1 || { echo "FAIL  plain-shell block $i:"; cat "$f"; cat "$work/plain-$i.log"; exit 1; }
    continue
  fi
  run_block "$f" || { dump_windows; exit 1; }
  # STOP_AFTER: a pattern; the run ends after the first block that matches it, with every window's history printed
  if [ -n "${STOP_AFTER:-}" ] && grep -q -- "$STOP_AFTER" "$f"; then echo "stopped after block $i"; dump_windows; exit 0; fi
  if [[ "$first" =~ ^tmux\ select-window\ -t\ ([a-z]+) ]]; then
    next=${BASH_REMATCH[1]}
    sleep 1                       # the switcher also typed ". ../env.sh" into the window it goes to
    current=$next
  fi
done
echo "ok    all $n blocks ran"

# ---- what the windows show, for the log and the error scan
for w in alice bob devnet; do tmux capture-pane -p -S - -t "demo:$w" > "$work/window-$w.log" 2>/dev/null || true; done
cat "$work"/window-alice.log "$work"/window-bob.log > "$work/log.txt"

# ---- checks
fail=0
check() { if jq -e "$2" "$1" >/dev/null 2>&1; then echo "ok    $1  $2"; else echo "FAIL  $1  $2"; fail=1; fi; }
. "$HOME/singular-demo-run/env.sh"   # jq for the checks
cd "$HOME/singular-demo-run"
check alice/receipts/01-create.json '.outcome=="success"'
if grep -q 'processTime' alice/receipts/02-describe.txt 2>/dev/null; then echo "ok    alice/receipts/02-describe.txt  shows the registry's rules"; else echo "FAIL  alice/receipts/02-describe.txt  no registry page"; fail=1; fi
check alice/receipts/03-insert-alice.json '.outcome=="success"'
check bob/receipts/04-fold-insert.json '.outcome=="waiting-for-signatures"'
check bob/receipts/04-fold-insert.submitted.json '(.submissions|length)>=1'
check alice/receipts/05-inspect.json '.leaf=="active"'
check alice/receipts/06-update.json '.outcome=="success"'
check alice/receipts/08-terminate.json '.outcome=="success"'
check bob/receipts/09-fold-terminate.json '.outcome=="waiting-for-signatures"'
check alice/receipts/10-inspect.json '.leaf=="terminal"'
check bob/receipts/11b-reject-too-early.json '.outcome=="client-refusal"'
check bob/receipts/11d-reject.json '.outcome=="waiting-for-signatures"'
check bob/receipts/12-insert-bob.json '.outcome=="waiting-for-signatures"'
check alice/receipts/13-fold-bob.json '.outcome=="success"'
check alice/receipts/14b-reclaim-too-early.json '.outcome=="client-refusal"'
check alice/receipts/14c-reclaim.json '.outcome=="success"'
check alice/receipts/15-insert-dave.json '.outcome=="success"'
check alice/receipts/16b-inspect-dave.json '.leaf=="active"'
if grep -qE "$ERROR_LINES" "$work/log.txt"; then echo "FAIL  an error line on the screens:"; grep -nE "$ERROR_LINES" "$work/log.txt" | head -5; fail=1; else echo "ok    no jq, curl, missing-file or command error on the screens"; fi
if tmux list-windows -t demo 2>/dev/null | grep -q devnet; then echo "FAIL  the devnet window is still there"; fail=1; else echo "ok    the devnet window is gone"; fi
if pgrep -f 'devnet --fund' >/dev/null; then echo "FAIL  a devnet process is still running"; fail=1; else echo "ok    no devnet process left"; fi
echo "RESULT: $([ $fail = 0 ] && echo PASS || echo FAIL)"
[ $fail = 0 ] || { echo "--- alice window, last lines:"; tail -12 "$work/window-alice.log"; echo "--- bob window, last lines:"; tail -12 "$work/window-bob.log"; }
exit $fail
