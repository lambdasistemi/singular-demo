#!/usr/bin/env bash
# Runs a generated Killercoda scenario the way Killercoda runs it, on a clean Ubuntu with no Nix, in REAL tmux windows:
#   node demos/demo1/killercoda.js /tmp/out
#   docker run --rm --memory 8g -v /tmp/scenario:/scenario:ro -v "$PWD":/repo:ro ubuntu:24.04 \
#     bash /repo/demos/demo1/scenario-test.sh /scenario     (/scenario is /tmp/out/killercoda/demo1-steps)
# 1. the machine gets curl (Killercoda's has it); the scenario's intro/background.sh runs (kit, tmux, settings files),
#    then intro/foreground.sh (the three tmux windows)
# 2. the click-to-run blocks of every step, in the order of index.json, then of the finish page, are TYPED into the
#    tmux window the learner is in, each followed by waiting for the shell's prompt; a block that is one of the words
#    alice, bob or chain moves the learner to that window (no key is needed anywhere: the chain is a background job of its
#    window, which keeps its prompt); a passphrase prompt on the screen fails the test (the windows carry SINGULAR_PASSPHRASE);
#    the chain is stopped at the end by the block of the finish page (kill %1)
# 3. the receipts of Alice's and Bob's directories are checked
# KIT_BASE=file:///dir takes the kit from a folder instead of the release page (a kit not published yet); the
# setup script reads it as PLAY_KIT_BASE
set -u
scenario=$(cd "${1:?usage: scenario-test.sh SCENARIO_DIR}" && pwd)
here=$(cd "$(dirname "$0")" && pwd)
bash "$here/lint.sh" "$scenario"/*/text.md || exit 1
export HOME=/root TERM=xterm-256color
cd "$HOME" || exit 1
if ! command -v curl >/dev/null; then apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null; fi
work=$(mktemp -d /tmp/sc-XXXXXX)
# KIT_BASE=file:///dir (a folder with the kit tarball and SHA256SUMS) tests a kit that is not published yet
background="$scenario/intro/background.sh"
[ -z "${KIT_BASE:-}" ] || export PLAY_KIT_BASE="$KIT_BASE"
if ! bash "$background" >"$work/background.log" 2>&1 || [ ! -f /tmp/finished ]; then
  echo "FAIL  intro/background.sh did not finish"
  tail -8 "$work/background.log"
  exit 1
fi
echo "ok    intro/background.sh finished"
# no kit on the PATH here on purpose: as on Killercoda, the tmux server starts from a plain shell without it
if ! bash "$scenario/intro/foreground.sh" >"$work/foreground.log" 2>&1 || ! grep -q '^Ready' "$work/foreground.log"; then
  echo "FAIL  intro/foreground.sh did not say Ready"
  tail -8 "$work/foreground.log"
  exit 1
fi
if [ "$(tmux list-windows -t demo -F '#{window_index}:#{window_name}' | tr '\n' ' ')" != "0:alice 1:bob 2:chain " ]; then
  echo "FAIL  the windows are not 0:alice 1:bob 2:chain:"
  tmux list-windows -t demo
  exit 1
fi
echo "ok    intro/foreground.sh said Ready; windows 0:alice 1:bob 2:chain"
for w in alice bob chain; do tmux resize-window -t "demo:$w" -x 200 -y 50; done
kit=$(find "$HOME" -maxdepth 1 -type d -name 'singular-demo-*-linux' | head -1)

# ---- the blocks, one file each
# an item is a click-to-run block
pages="$(grep -o '"text": *"[^"]*"' "$scenario/index.json" | cut -d'"' -f4)"
n=0
for p in $pages; do
  awk -v dir="$work" -v start="$n" '
    /^```bash$/ {inb=1; buf=""; next}
    inb && /^```\{\{exec\}\}$/ {start++; f=sprintf("%s/blk-%04d", dir, start); printf "%s", buf > f; close(f); inb=0; next}
    inb && /^```$/ {inb=0; next}
    inb {buf = buf $0 "\n"; next}
    END {print start > (dir "/.last")}' "$scenario/$p"
  n=$(cat "$work/.last")
done
echo "ok    $n click-to-run blocks from $(echo "$pages" | wc -w) pages"
# shellcheck disable=SC2016 # the backtick is part of the text searched for
if grep -rqE 'Press `Ctrl|press `Ctrl\+C' "$scenario"/*/text.md; then
  echo "FAIL  a page asks for a key that a tablet does not have:"
  grep -rnE 'Press `Ctrl|press `Ctrl\+C' "$scenario"/*/text.md
  exit 1
fi
echo "ok    no page requires a key press (Ctrl-b is only offered as an extra to the words)"

# ---- the terminal
declare -A started
current="" # the tmux window the learner is in; empty before "tmux attach"

tx() {
  tmux send-keys -t "demo:$1" -l -- "$2"
  tmux send-keys -t "demo:$1" Enter
}

init_window() { # the shell of a window reports each prompt it shows, so the driver knows when a command is over
  local w=$1
  [ -n "${started[$w]:-}" ] && return
  : >"/tmp/prompts-$w"
  tx "$w" "PS1='\$ '; PROMPT_COMMAND='echo p >> /tmp/prompts-$w'"
  local i
  for i in $(seq 1 100); do
    [ -s "/tmp/prompts-$w" ] && break
    sleep 0.2
  done
  started[$w]=1
}

ERROR_LINES='jq: error|command not found|curl: [(]|No such file or directory|Uncaught exception|integer expression expected'
run_block() {
  local file=$1 w=$current
  local expected
  expected=$(awk 'NF && $0 !~ /\\$/ {c++} END {print c+0}' "$file")
  init_window "$w"
  local base
  base=$(wc -l <"/tmp/prompts-$w")
  local hist0
  hist0=$(tmux capture-pane -p -J -S - -t "demo:$w" | grep -c .)
  local line
  while IFS= read -r line; do tx "$w" "$line"; done <"$file"
  local waited=0
  while :; do
    local have
    have=$(wc -l <"/tmp/prompts-$w")
    [ "$have" -ge $((base + expected)) ] && break
    # one snapshot of the screen, so the last line is read from one moment
    local snap
    snap=$(tmux capture-pane -p -J -S - -t "demo:$w" | grep .)
    if printf '%s\n' "$snap" | tail -1 | grep -qi 'passphrase: *$'; then
      echo "FAIL  a passphrase prompt appeared in window $w; the windows carry SINGULAR_PASSPHRASE:"
      cat "$file"
      return 1
    fi
    sleep 0.4
    waited=$((waited + 1))
    if [ "$waited" -gt 3000 ]; then
      echo "FAIL  block timed out in window $w:"
      cat "$file"
      echo "--- screen:"
      tmux capture-pane -p -t "demo:$w" | grep . | tail -8
      return 1
    fi
  done
  # what this block printed must hold no error line (a missing file, a failed jq, a missing command)
  local bad
  bad=$(tmux capture-pane -p -J -S - -t "demo:$w" | grep . | tail -n +$((hist0 + 1)) | grep -E "$ERROR_LINES" | head -3)
  if [ -n "$bad" ]; then
    echo "FAIL  error line on the screen of window $w after this block:"
    cat "$file"
    echo "--- error lines:"
    echo "$bad"
    return 1
  fi
}

dump_windows() {
  local w
  for w in alice bob chain; do
    echo "=== window $w:"
    tmux capture-pane -p -S - -t "demo:$w" 2>/dev/null | grep . | tail -"${DUMP_LINES:-60}"
  done
}

for i in $(seq 1 "$n"); do
  f=$(printf '%s/blk-%04d' "$work" "$i")
  first=$(head -1 "$f")
  case "$first" in
    "tmux attach -t demo"*)
      current=alice
      echo "ok    attached; the learner is in the window alice"
      continue
      ;;
    alice | bob | chain)
      [ -n "$current" ] || {
        echo "FAIL  block $i goes to a window before the learner attached"
        exit 1
      }
      run_block "$f" || {
        dump_windows
        exit 1
      }
      current=$first
      echo "ok    the word $first: the learner is in the window $current"
      continue
      ;;
  esac
  if [ -z "$current" ]; then
    # before tmux attach the learner is in the plain shell
    bash "$f" >"$work/plain-$i.log" 2>&1 || {
      echo "FAIL  plain-shell block $i:"
      cat "$f"
      cat "$work/plain-$i.log"
      exit 1
    }
    continue
  fi
  if [ "$current" = chain ]; then
    # the chain is a background job of its window: the window gets its prompt back, and only the chain's start and stop belong here
    case "$first" in
      "devnet --fund"* | "kill %1") ;;
      *)
        echo "FAIL  a block other than the chain's start or stop runs in the window chain:"
        cat "$f"
        exit 1
        ;;
    esac
  fi
  run_block "$f" || {
    dump_windows
    exit 1
  }
  # STOP_AFTER: a pattern; the run ends after the first block that matches it, with every window's history printed
  if [ -n "${STOP_AFTER:-}" ] && grep -q -- "$STOP_AFTER" "$f"; then
    echo "stopped after block $i"
    dump_windows
    exit 0
  fi
done
echo "ok    all $n items ran"
[ "$current" = chain ] || {
  echo "FAIL  the finish page did not take the learner to the window chain (now: $current)"
  exit 1
}
grep -q '^kill %1$' "$scenario/finish/text.md" || {
  echo "FAIL  the finish page does not stop the chain with kill %1"
  exit 1
}
sleep 3

# ---- what the windows show, for the log and the error scan
for w in alice bob chain; do tmux capture-pane -p -S - -t "demo:$w" >"$work/window-$w.log" 2>/dev/null || true; done
cat "$work"/window-alice.log "$work"/window-bob.log >"$work/log.txt"

# ---- checks
fail=0
check() { if jq -e "$2" "$1" >/dev/null 2>&1; then echo "ok    $1  $2"; else
  echo "FAIL  $1  $2"
  fail=1
fi; }
export PATH="$kit/bin:$PATH" # jq for the checks
cd "$HOME/singular-demo-run" || exit 1
check alice/receipts/01-create.json '.outcome=="success"'
check alice/receipts/02-describe.json '.outcome=="success" and .rules.processTime>0'
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
if grep -qE "$ERROR_LINES" "$work/log.txt"; then
  echo "FAIL  an error line on the screens:"
  grep -nE "$ERROR_LINES" "$work/log.txt" | head -5
  fail=1
else echo "ok    no jq, curl, missing-file or command error on the screens"; fi
if grep -q 'devnet: funded' devnet.log; then echo "ok    the chain's messages are in devnet.log"; else
  echo "FAIL  no chain message in devnet.log"
  fail=1
fi
if grep -q 'devnet: funded' "$work/window-chain.log"; then
  echo "FAIL  chain messages still print in the window chain"
  fail=1
else echo "ok    the window chain stays clean: the messages go to the file"; fi
if pgrep -f 'devnet --fund|cardano-node' >/dev/null; then
  echo "FAIL  a devnet or cardano-node process is still running after kill %1:"
  pgrep -af 'devnet --fund|cardano-node' | cut -c1-120
  fail=1
else echo "ok    kill %1 stopped the chain: no devnet and no cardano-node process left"; fi
if tmux list-windows -t demo -F '#{window_name}' | grep -q '^chain$'; then echo "ok    the window chain keeps its shell"; else
  echo "FAIL  the window chain is gone"
  fail=1
fi
echo "RESULT: $([ $fail = 0 ] && echo PASS || echo FAIL)"
[ $fail = 0 ] || {
  echo "--- alice window, last lines:"
  tail -12 "$work/window-alice.log"
  echo "--- bob window, last lines:"
  tail -12 "$work/window-bob.log"
}
exit $fail
