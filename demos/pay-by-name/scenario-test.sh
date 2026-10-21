#!/usr/bin/env bash
# Runs the generated Killercoda scenario of the pay-by-name story the way Killercoda runs it, on a clean Ubuntu with no Nix, in REAL
# tmux windows, and then the controls that only the tests run:
#   bash tools/generate.sh /tmp/out
#   docker run --rm --memory 12g -e KIT_BASE=file:///kit -v /tmp/out/killercoda/pay-by-name-steps:/scenario:ro \
#     -v "$PWD":/repo:ro -v /tmp/kit:/kit:ro ubuntu:24.04 bash /repo/demos/pay-by-name/scenario-test.sh /scenario
#   /kit holds the kit tarball with its SHA256SUMS, and controls.cjs (the test-only controls: nix build .#pay-by-name-tools)
# 1. the machine gets curl (Killercoda's has it); the scenario's intro/background.sh runs (kit, tmux, node), then
#    intro/foreground.sh (the five tmux windows)
# 2. the click-to-run blocks of every step are TYPED into the tmux window the learner is in, each followed by waiting for the shell's
#    prompt; a block that is one of the words carol, alice, dave, bob or chain moves the learner to that window; a passphrase
#    prompt on the screen fails the test (the windows carry SINGULAR_PASSPHRASE)
# 3. the story's files and screens are checked
# 4. the controls: a stranger moves the money; an attacker, a forged output, another registry, a missing reference, two sinks in one
#    transaction (and the variant without the check that stops it), a datum hash, an inline datum; a registry checked against a wrong
#    state output and against a foreign application; a name ended and booked again; a dead sink. Each asserts its label or outcome.
# 5. the finish page stops the chain (kill %1)
# KIT_BASE=file:///dir takes the kit from a folder instead of the release page (a kit not published yet); the setup script
# reads it as PLAY_KIT_BASE. CONTROLS names the test-only controls (default /kit/controls.cjs).
# shellcheck disable=SC2015 # "A && ok || bad" is meant: ok only prints, so bad cannot follow a passing check
set -u
scenario=$(cd "${1:?usage: scenario-test.sh SCENARIO_DIR}" && pwd)
here=$(cd "$(dirname "$0")" && pwd)
CONTROLS=${CONTROLS:-/kit/controls.cjs}
bash "$here/../demo1/lint.sh" "$scenario"/*/text.md || exit 1
export HOME=/root TERM=xterm-256color
cd "$HOME" || exit 1
df -h / | tail -1
if ! command -v curl >/dev/null; then apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null; fi
work=$(mktemp -d /tmp/sc-XXXXXX)
background="$scenario/intro/background.sh"
[ -z "${KIT_BASE:-}" ] || export PLAY_KIT_BASE="$KIT_BASE"
if ! bash "$background" >"$work/background.log" 2>&1 || [ ! -f /tmp/finished ]; then
  echo "FAIL  intro/background.sh did not finish"
  tail -8 "$work/background.log"
  exit 1
fi
echo "ok    intro/background.sh finished ($(tmux -V))"
# no kit on the PATH here on purpose: as on Killercoda, the tmux server starts from a plain shell without it
if ! bash "$scenario/intro/foreground.sh" >"$work/foreground.log" 2>&1 || ! grep -q '^Ready' "$work/foreground.log"; then
  echo "FAIL  intro/foreground.sh did not say Ready"
  tail -8 "$work/foreground.log"
  exit 1
fi
if [ "$(tmux list-windows -t demo -F '#{window_index}:#{window_name}' | tr '\n' ' ')" != "0:carol 1:alice 2:dave 3:bob 4:chain " ]; then
  echo "FAIL  the windows are not 0:carol 1:alice 2:dave 3:bob 4:chain:"
  tmux list-windows -t demo
  exit 1
fi
echo "ok    intro/foreground.sh said Ready; windows 0:carol 1:alice 2:dave 3:bob 4:chain"
WINDOWS="carol alice dave bob chain"
for w in $WINDOWS; do tmux resize-window -t "demo:$w" -x 200 -y 50; done
kit=$(find "$HOME" -maxdepth 1 -type d -name 'singular-demo-*-linux' | head -1)
run=$HOME/singular-demo-run

# ---- the blocks, one file each; the pages of the steps first, then the finish page
pages="$(grep -o '"text": *"[^"]*"' "$scenario/index.json" | cut -d'"' -f4 | grep -v '^finish/')"
blocks_of() { # PAGE... : numbers the blocks of the pages from $n on
  local p
  for p in "$@"; do
    awk -v dir="$work" -v start="$n" '
      /^```bash$/ {inb=1; buf=""; next}
      inb && /^```\{\{exec\}\}$/ {start++; f=sprintf("%s/blk-%04d", dir, start); printf "%s", buf > f; close(f); inb=0; next}
      inb && /^```$/ {inb=0; next}
      inb {buf = buf $0 "\n"; next}
      END {print start > (dir "/.last")}' "$scenario/$p"
    n=$(cat "$work/.last")
  done
}
n=0
# shellcheck disable=SC2086 # the pages are separate words
blocks_of $pages
steps_end=$n
blocks_of finish/text.md
echo "ok    $steps_end click-to-run blocks in the steps, $((n - steps_end)) in the finish page"
# shellcheck disable=SC2016 # the backtick is part of the text searched for
if grep -rqE 'Press `Ctrl|press `Ctrl\+C' "$scenario"/*/text.md; then
  echo "FAIL  a page asks for a key that a tablet does not have"
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
    local snap
    snap=$(tmux capture-pane -p -J -S - -t "demo:$w" | grep .)
    if printf '%s\n' "$snap" | tail -1 | grep -qi 'passphrase: *$'; then
      echo "FAIL  a passphrase prompt appeared in window $w; the windows carry SINGULAR_PASSPHRASE:"
      cat "$file"
      return 1
    fi
    sleep 0.4
    waited=$((waited + 1))
    if [ "$waited" -gt 1500 ]; then
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
  for w in $WINDOWS; do
    echo "=== window $w:"
    tmux capture-pane -p -S - -t "demo:$w" 2>/dev/null | grep . | tail -"${DUMP_LINES:-60}"
  done
}

play_block() { # N : types block N, or moves the learner; the chain window takes only its own commands
  local i=$1 f first
  f=$(printf '%s/blk-%04d' "$work" "$i")
  first=$(head -1 "$f")
  case "$first" in
    "tmux attach -t demo"*)
      current=carol
      echo "ok    attached; the learner is in the window carol"
      return 0
      ;;
    carol | alice | dave | bob | chain)
      [ -n "$current" ] || {
        echo "FAIL  block $i goes to a window before the learner attached"
        return 1
      }
      run_block "$f" || return 1
      current=$first
      echo "ok    the word $first: the learner is in the window $current"
      return 0
      ;;
  esac
  if [ -z "$current" ]; then
    bash "$f" >"$work/plain-$i.log" 2>&1 || {
      echo "FAIL  plain-shell block $i:"
      cat "$f"
      cat "$work/plain-$i.log"
      return 1
    }
    return 0
  fi
  if [ "$current" = chain ]; then
    # the chain is a background job of its window: only its start, the wait for its settings line and its stop belong there
    case "$first" in
      "devnet --fund"* | "until jq -e .providerUrl devnet.out"* | "kill %1") ;;
      *)
        echo "FAIL  a block other than the chain's start, wait or stop runs in the window chain:"
        cat "$f"
        return 1
        ;;
    esac
  fi
  run_block "$f"
}

for i in $(seq 1 "$steps_end"); do
  play_block "$i" || {
    dump_windows
    exit 1
  }
done
echo "ok    all $steps_end blocks of the steps ran"
sleep 2
for w in $WINDOWS; do tmux capture-pane -p -S - -t "demo:$w" >"$work/window-$w.log" 2>/dev/null || true; done
cat "$work"/window-{carol,alice,dave,bob}.log >"$work/log.txt"

# ---- the story
fail=0
ok() { echo "ok    $1"; }
bad() {
  echo "FAIL  $1"
  fail=1
}
export PATH="$kit/bin:$PATH" # jq for the checks
export blueprint="$kit/share/plutus.json" SINGULAR_PASSPHRASE=demo
check() { if jq -e "$2" "$1" >/dev/null 2>&1; then ok "$1  $2"; else bad "$1  $2"; fi; }
cd "$run" || exit 1
bash "$here/check-run.sh" "$run" "$work" || fail=1
if grep -qE "$ERROR_LINES" "$work/log.txt"; then
  bad "an error line on the screens"
  grep -nE "$ERROR_LINES" "$work/log.txt" | head -5
else ok "no jq, curl, missing-file or command error on the screens"; fi
# the money: Alice's sink holds 30 - 7 - 10 = 13 ada, Dave's 15 - 5 = 10 ada
# the helpers the windows have (settings, koios_url, outputs_at); a startup file may use a variable it did not set
set +u
# shellcheck source=/dev/null
. "$run/windows.rc"
set -u
sink_ada() { curl -s -X POST "$(koios_url)/address_utxos" -H 'content-type: application/json' -d "{\"_addresses\":[\"$1\"]}" | jq '[.[] | (.value|tonumber)] | add / 1000000'; }
[ "$(sink_ada "$(jq -r .address bob/sink-alice.json)")" = 13 ] && ok "Alice's sink holds 13 ada" || bad "Alice's sink does not hold 13 ada"
[ "$(sink_ada "$(jq -r .address bob/sink-dave.json)")" = 10 ] && ok "Dave's sink holds 10 ada" || bad "Dave's sink does not hold 10 ada"
active1=$(jq -r .registry.activeScript alice/describe.json)
token1=$(jq -r '."state-token"' alice/singular.json)

# ---- the controls
echo "== controls: $(df -h / | tail -1)"
node "$CONTROLS" keys "$run/keys" stranger attacker
echo "== the test roles get money from Bob, by the bundle route"
(
  cd bob || exit 1
  sink-tools pay --from "$(cat bob.address)" --out "$(cat ../keys/stranger.address):500000000" --out "$(cat ../keys/attacker.address):500000000" --bundle roles.bundle &&
    singular wallet sign --vault bob.vault --out witnesses-roles roles.bundle >/dev/null 2>&1 &&
    singular submit --witnesses witnesses-roles --receipt roles.submitted.json roles.bundle >roles.submit.out
) && check bob/roles.submitted.json '.outcome=="success"' || bad "the test roles were not funded"

echo "== a stranger moves 2 ada of Alice's money: anyone may; it goes to the address registered now (alice2)"
(
  cd alice || exit 1
  sink-tools move --active-policy "$active1" --name alice --sk ../keys/stranger.sk --lovelace 2000000 >stranger.out 2>&1
)
cat alice/stranger.out
tx=$(sed -n 's/^transaction \([0-9a-f]*\) submitted and confirmed$/\1/p' alice/stranger.out)
[ -n "$tx" ] && [ "$(curl -s -X POST "$(koios_url)/address_utxos" -H 'content-type: application/json' -d "{\"_addresses\":[\"$(cat alice/alice2.address)\"]}" | jq --arg tx "$tx" '[.[] | select(.tx_hash == $tx) | .value] | join(",")' -r)" = 2000000 ] &&
  ok "T-stranger: ACCEPTED, tx $tx, 2000000 lovelace at alice2's address" || bad "T-stranger: the stranger's move did not land at alice2's address"

echo "== Alice books alice-tips at the same address (needed by the two-sinks control)"
(
  cd alice || exit 1
  open-datum insert --key alice-tips --payload payload-new.json --vault alice.vault >insert-tips.json &&
    open-datum fold --vault alice.vault >fold-tips.json
) && check alice/insert-tips.json '.outcome=="success"' && check alice/fold-tips.json '.outcome=="success"' || bad "alice-tips was not booked and folded"

echo "== the attacker's own registry, with the key alice pointing at the attacker (a key file, no vault)"
mkdir -p attacker
(
  cd attacker || exit 1
  settings
  open-datum create --wallet-skey ../keys/attacker.skey >create.json &&
    settings "$(jq -r .stateToken create.json)" &&
    sink-tools addr-json "$(cat ../keys/attacker.address)" >payload.json &&
    open-datum insert --key alice --payload payload.json --wallet-skey ../keys/attacker.skey >insert.json &&
    open-datum fold --wallet-skey ../keys/attacker.skey >fold.json &&
    singular registry describe --blueprint "$blueprint" >describe.json
) && check attacker/fold.json '.outcome=="success"' || bad "the attacker's registry was not made"
active2=$(jq -r .registry.activeScript attacker/describe.json)
[ "$active1" != "$active2" ] && ok "the two registries have different active policies" || bad "the active policies are the same"

echo "== the sink's controls (attacker, forged, second registry, no reference, datum hash, inline datum, two sinks and the variant)"
(cd alice && SINGULAR_CONFIG="$run/alice/singular.json" node "$CONTROLS" controls "$run" "$active1" "$active2") >"$work/controls.log" 2>&1
rc=$?
grep -E '^(---|ACCEPTED|REJECTED|  local|  node|  same|CONTROL|=== |PASS|FAIL)' "$work/controls.log" | cut -c1-260
if [ $rc = 0 ] && grep -q '^=== 10 of 10 controls as expected' "$work/controls.log"; then ok "10 of 10 controls as expected"; else
  bad "the controls: exit $rc"
  tail -20 "$work/controls.log"
fi
for label in sink-conservation sink-token sink-no-reference sink-datum-hash sink-foreign-script; do
  grep -q "same bytes, local evaluator: .*Trace $label" "$work/controls.log" && ok "a refusal with $label, read from the exact bytes the node refused" || bad "no refusal with $label in the controls"
done

echo "== check-registry on Alice's registry against the attacker's state output: must not match"
(cd alice && sink-tools check-registry --state-token "$token1" --state-output "$(jq -r .registry.stateOutput ../attacker/describe.json)") >"$work/wrong-output.log" 2>&1
rc=$?
cat "$work/wrong-output.log"
[ $rc = 1 ] && grep -q '^application: does not match' "$work/wrong-output.log" && ok "check-registry against a wrong state output: application does not match, exit 1" || bad "check-registry against a wrong state output (exit $rc)"

echo "== a registry that pins a foreign application: describe accepts it, check-registry does not"
mkdir -p bogus
(
  cd bogus || exit 1
  settings
  bogus_policy=$(node -e 'console.log(require("crypto").randomBytes(28).toString("hex"))')
  echo "pinned at creation: $bogus_policy"
  singular registry create --application-policy "$bogus_policy" --vault ../bob/bob.vault >create.json &&
    settings "$(jq -r .stateToken create.json)" &&
    singular registry describe --blueprint "$blueprint" >describe.json
  echo "describe exit $?; it prints applicationScript $(jq -r .registry.applicationScript describe.json)"
  [ "$(jq -r .registry.applicationScript describe.json)" = "$bogus_policy" ]
) && ok "describe accepted the registry and printed the foreign application, without a word" || bad "describe did not accept the registry that pins a foreign application"
(cd bogus && sink-tools check-registry describe.json) >"$work/foreign.log" 2>&1
rc=$?
cat "$work/foreign.log"
[ $rc = 1 ] && grep -q '^application: does not match' "$work/foreign.log" && ok "check-registry on the foreign application: does not match, exit 1" || bad "check-registry on the foreign application (exit $rc)"
echo "== a published sink script that is not the validator applied to this registry's active policy"
(
  cd alice || exit 1
  jq --arg s "$(sink-tools registry-sink --active-policy "$(jq -r .registry.activeScript ../bogus/describe.json)")" '."sink-script" = $s' ../publish/registry.json >../bogus/registry-tampered.json
  sink-tools check-registry describe.json --published ../bogus/registry-tampered.json
) >"$work/tampered.log" 2>&1
rc=$?
tail -3 "$work/tampered.log"
[ $rc = 1 ] && grep -q '^published registry sink script: does not match' "$work/tampered.log" && ok "a tampered published sink script: does not match, exit 1" || bad "the tampered published sink script (exit $rc)"

echo "== Alice ends the name alice; the attacker books it again; nobody can fold it; the sink is dead"
stale=$(cd alice && open-datum inspect --key alice | jq -r .applicationOutput.output)
(
  cd alice || exit 1
  open-datum terminate --key alice --vault alice.vault >terminate.json &&
    open-datum fold --vault alice.vault >fold-terminate.json &&
    open-datum inspect --key alice >inspect-terminal.json
) && check alice/inspect-terminal.json '.leaf=="terminal"' || bad "alice was not ended"
mkdir -p attacker1
(
  cd attacker1 || exit 1
  settings "$token1"
  open-datum insert --key alice --payload ../attacker/payload.json --wallet-skey ../keys/attacker.skey >insert.json
  echo "insert exit $?"
  jq -c '{outcome, reason}' insert.json
)
check attacker1/insert.json '.outcome=="client-refusal" and (.reason|test("alice is already retired"))'
(
  cd dave || exit 1
  open-datum fold --vault dave.vault >fold-rebook.json
  echo "fold exit $?"
  jq -c '{outcome, reason}' fold-rebook.json
)
check dave/fold-rebook.json '.outcome=="client-refusal" and (.reason|test("nothing is pending"))'
(cd alice && sink-tools move --active-policy "$active1" --name alice --sk ../keys/stranger.sk --lovelace 1000000) >"$work/dead-move.log" 2>&1
rc=$?
cat "$work/dead-move.log"
[ $rc = 1 ] && grep -q 'no live registry output holds the key "alice"' "$work/dead-move.log" && ok "a move from the dead sink: no registry output, exit 1" || bad "a move from the dead sink (exit $rc)"
(cd alice && SINGULAR_CONFIG="$run/alice/singular.json" node "$CONTROLS" dead "$run" "$active1" "$stale") >"$work/dead.log" 2>&1
rc=$?
cat "$work/dead.log"
[ $rc = 0 ] && grep -q 'live outputs holding the token (active policy, "alice"): 0' "$work/dead.log" && grep -q 'CONTROL PASS' "$work/dead.log" && ok "no live token afterwards, and a move built on the old registry output is refused by the node (BadInputsUTxO)" || bad "the dead sink (exit $rc)"

# ---- the finish page stops the chain
for i in $(seq $((steps_end + 1)) "$n"); do
  play_block "$i" || {
    dump_windows
    exit 1
  }
done
echo "ok    the finish page's blocks ran"
[ "$current" = chain ] || bad "the finish page did not take the learner to the window chain (now: $current)"
grep -q '^kill %1$' "$scenario/finish/text.md" || bad "the finish page does not stop the chain with kill %1"
sleep 3
for w in $WINDOWS; do tmux capture-pane -p -S - -t "demo:$w" >"$work/window-$w.log" 2>/dev/null || true; done
if grep -q 'devnet: funded' "$run/devnet.log"; then ok "the chain's messages are in devnet.log"; else bad "no chain message in devnet.log"; fi
if grep -q 'devnet: funded' "$work/window-chain.log"; then bad "chain messages still print in the window chain"; else ok "the window chain stays clean: the messages go to the file"; fi
if pgrep -f 'devnet --fund|cardano-node' >/dev/null; then
  bad "a devnet or cardano-node process is still running after kill %1"
  pgrep -af 'devnet --fund|cardano-node' | cut -c1-120
else ok "kill %1 stopped the chain: no devnet and no cardano-node process left"; fi
echo "RESULT: $([ $fail = 0 ] && echo PASS || echo FAIL)"
[ $fail = 0 ] || {
  for w in carol alice dave bob; do
    echo "--- $w window, last lines:"
    tail -12 "$work/window-$w.log"
  done
}
exit $fail
