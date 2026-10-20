#!/usr/bin/env bash
# ============================================================================
# Singular v0.13.1 — Demo 1 on a private development chain (devnet).
#
# Alice runs an "open datum" registry: a table of keys, each holding a small
# piece of data that only its owner may change. The script walks the whole
# life of that registry in 16 steps, using only the programs in this kit.
#
# How to read this file: every line that starts with "#|" is the explanation
# of the command that follows it. The script prints those lines on the screen
# just before it runs the command, so what you read here is what the audience
# reads there. Lines that start with a plain "#" are notes for the maintainer.
# In a "#|" line, @PROCESS_S@ and @RETRACT_S@ stand for the two windows in seconds.
#
#   ./demo.sh                               run everything, devnet included
#   DEVNET_MODE=other-terminal ./demo.sh    you start the devnet yourself
#   STEP_PAUSE=yes ./demo.sh                wait for Enter after each step
#   WORK=/some/dir ./demo.sh                where the run's files are kept
#   PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000 ./demo.sh
#                                           shorter windows, so the two waits are shorter
#                                           (defaults 120000 and 60000; least allowed 60000 and 30000)
# ============================================================================
set -euo pipefail

# ---- THE ONE SWITCH --------------------------------------------------------
#   own             (default) this script starts the private chain, uses it, and
#                   stops it when it ends or when you press Ctrl-C.
#   other-terminal  you start the chain in a second terminal; this script prints
#                   the one command to type there, waits for the chain, and
#                   leaves it running when it ends.
DEVNET_MODE=${DEVNET_MODE:-own}
# -----------------------------------------------------------------------------
STEP_PAUSE=${STEP_PAUSE:-no}
TOTAL=16
PROCESS_TIME_MS=${PROCESS_TIME_MS:-120000}   # the window in which the registry may fold a request (default 2 minutes)
RETRACT_TIME_MS=${RETRACT_TIME_MS:-60000}     # the window after it in which the owner may take it back (default 1 minute)

SCRIPT=$(readlink -f "${BASH_SOURCE[0]}")
KIT=$(dirname "$SCRIPT")
[ -x "$KIT/bin/singular" ] || { echo "demo.sh must sit in the kit's top directory, next to bin/" >&2; exit 2; }
export PATH="$KIT/bin:$PATH"
WORK=${WORK:-$PWD/singular-demo-run}
mapfile -t SRC < "$SCRIPT"

if [ -t 1 ]; then
  B=$'\033[1m'; D=$'\033[2m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; C=$'\033[36m'; Z=$'\033[0m'
else
  B=; D=; G=; Y=; R=; C=; Z=
fi

# ---- small helpers (the audience does not need to read these) ---------------
die() { printf '\n%s%s%s\n' "$R" "stopped: $*" "$Z" >&2; exit 1; }

# the two windows come from the environment; refuse values that cannot work
case "$PROCESS_TIME_MS$RETRACT_TIME_MS" in *[!0-9]*|'') echo "PROCESS_TIME_MS and RETRACT_TIME_MS must be whole numbers of milliseconds." >&2; exit 2;; esac
if [ "$PROCESS_TIME_MS" -lt 60000 ]; then
  echo "PROCESS_TIME_MS=$PROCESS_TIME_MS is too short: the fold of each booking has to be built, signed and sent inside this window. Use 60000 (one minute) or more." >&2; exit 2
fi
if [ "$RETRACT_TIME_MS" -lt 30000 ]; then
  echo "RETRACT_TIME_MS=$RETRACT_TIME_MS is too short: the reclaim needs at least ten seconds of usable slots inside this window, and the command itself takes a few seconds more. Use 30000 (thirty seconds) or more." >&2; exit 2
fi
# span MS: a duration for the narration, in whole minutes when it is one, else in seconds
span() {
  local words=(zero one two three four five six seven eight nine ten) m
  if [ $(( $1 % 60000 )) -eq 0 ]; then
    m=$(( $1 / 60000 )); echo "${words[m]:-$m} minute$([ "$m" = 1 ] || echo s)"
  else
    echo "$(( $1 / 1000 )) seconds"
  fi
}

# why: print the "#|" comment block that sits directly above the line that called us
why() {
  local call=${1:-${BASH_LINENO[0]}} last first k line
  last=$(( call - 2 )); first=$last
  while [ "$first" -ge 0 ] && [[ "${SRC[first]}" == '#|'* ]]; do first=$(( first - 1 )); done
  first=$(( first + 1 ))
  for (( k = first; k <= last; k++ )); do
    line=${SRC[k]#'#|'}; line=${line# }
    line=${line//@PROCESS_S@/$(( PROCESS_TIME_MS / 1000 ))}; line=${line//@RETRACT_S@/$(( RETRACT_TIME_MS / 1000 ))}
    printf '    %s\n' "$line"
  done
}

step() { # step N "title" — heading, then the explanation written above this call
  local call=${BASH_LINENO[0]}
  CURRENT_STEP=$1
  printf '\n%s━━ Step %s of %s — %s%s\n' "$B" "$1" "$TOTAL" "$2" "$Z"
  why "$call"
}

section() { printf '\n%s━━ %s%s\n' "$B" "$1" "$Z"; why "${BASH_LINENO[0]}"; }
cmd()  { printf '\n  %s$ %s%s\n' "$C" "$1" "$Z"; }
more() { printf '    %s\n' "$@"; }
saved() { printf '    %sfull receipt: %s%s\n' "$D" "$1" "$Z"; }
shorten() { sed -E 's/([0-9a-f]{12})[0-9a-f]{20,}/\1…/g'; }

JQ_DEFS='
def s: if length > 16 then .[0:12] + "…" else . end;
def sr: split("#") as $p | ($p[0] | s) + "#" + $p[1];
def pad: . + (" " * (24 - length));
def row($k; $v): "    " + (($k + ":") | pad) + ($v | tostring);
def ada: . / 1000000 | tostring + " ada";
def unhex: [scan("..") | explode | map(if . >= 97 then . - 87 else . - 48 end) | .[0] * 16 + .[1]] | implode;
'
facts() { local file=$1; shift; jq -r "$JQ_DEFS $*" "$file"; }

# capture FILE EXPECTED_EXIT COMMAND... : run quietly, keep the receipt in FILE
capture() {
  local file=$1 want=$2 rc=0; shift 2
  "$@" > "$file" 2> "$file.err" || rc=$?
  if [ "$rc" -ne "$want" ]; then
    printf '\n%sunexpected exit status %s (expected %s) from: %s%s\n' "$R" "$rc" "$want" "$1 $2" "$Z" >&2
    jq -r '.outcome // empty, .reason // empty' "$file" 2>/dev/null >&2 || true
    head -c 2000 "$file.err" >&2 || true
    printf 'full output: %s and %s.err\n' "$file" "$file" >&2
    exit 1
  fi
}

pause_if_asked() {
  if [ "$STEP_PAUSE" = yes ]; then printf '\n%s[Enter for the next step]%s' "$D" "$Z"; read -r _ < /dev/tty || true; fi
}

tip_slot() { curl -fsS --max-time 5 "$KOIOS_URL/tip" | jq -er '.[0].abs_slot'; }

# wait_for_slot SLOT "what is being waited for": a countdown driven by the chain's own tip
wait_for_slot() {
  local target=$1 now left mark=-100
  while :; do
    now=$(tip_slot) || die "the devnet stopped answering"
    if [ "$now" -gt "$target" ]; then break; fi
    left=$(( ((target - now) * SLOT_MS + 999) / 1000 ))
    if [ -t 1 ]; then
      printf '\r\033[K    %s%d:%02d left%s  %s (chain tip: slot %d, needs more than slot %d)' "$Y" $((left/60)) $((left%60)) "$Z" "$2" "$now" "$target"
    elif [ $(( SECONDS - mark )) -ge 15 ]; then
      printf '    %d:%02d left  %s (chain tip: slot %d, needs more than slot %d)\n' $((left/60)) $((left%60)) "$2" "$now" "$target"
      mark=$SECONDS
    fi
    sleep 1
  done
  if [ -t 1 ]; then printf '\r\033[K'; fi
  printf '    %sdone:%s the chain tip is at slot %d, past slot %d\n' "$G" "$Z" "$now" "$target"
}

# Bob's external signing, in two commands: sign the bundle with his vault, then send it
bob_signs_and_sends() { # NAME STEP-PREFIX
  local name=$1 prefix=$2 first=${BOB_EXPLAINED:-no}
  BOB_EXPLAINED=yes
  if [ "$first" = no ]; then
    more "Exit status 19 is not an error: it means \"waiting for signatures\". The command wrote its" \
         "whole run as one bundle file and sent nothing. Bob's key never left his vault, so now:" \
         "  1. 'singular wallet sign' opens Bob's vault and signs the bundle (witnesses = signatures);" \
         "  2. 'singular submit' sends the signed bundle to the chain and waits until it has landed."
  else
    more "Exit status 19 again: bundle written, nothing sent. Sign it with Bob's vault, then send it."
  fi
  cmd "singular wallet sign --vault bob.vault --passphrase-fd 3 --out witnesses/$name bundles/$name.bundle   (passphrase: 3< bob.passphrase)"
  capture "receipts/$prefix-$name.signed.txt" 0 singular wallet sign --vault bob.vault --passphrase-fd 3 --out "witnesses/$name" "bundles/$name.bundle" 3< bob.passphrase
  sed -n '1p;2p' "receipts/$prefix-$name.signed.txt.err" | cut -d, -f1,2 | shorten | sed 's/^/    /'
  cmd "singular submit --witnesses witnesses/$name <provider> --receipt receipts/$prefix-$name.submitted.json bundles/$name.bundle"
  capture "receipts/$prefix-$name.submit.json" 0 singular submit --witnesses "witnesses/$name" "${PROVIDER[@]}" --receipt "receipts/$prefix-$name.submitted.json" "bundles/$name.bundle"
  facts "receipts/$prefix-$name.submitted.json" '.submissions[] | row("landed"; "slot \(.chainPoint.slot), \(.confirmations) confirmations"), row("effect"; .claims[0] | gsub("[0-9a-f]{12}[0-9a-f]{20,}"; "…"))'
  saved "receipts/$prefix-$name.submitted.json"
}

cleanup() {
  local rc=$?
  trap - EXIT INT TERM
  if [ -n "${DEVNET_PID:-}" ]; then
    printf '\n%sStopping the devnet this script started…%s' "$D" "$Z"
    kill -TERM -- "-$DEVNET_PID" 2>/dev/null || true
    for _ in $(seq 1 100); do
      kill -0 -- "-$DEVNET_PID" 2>/dev/null || break
      sleep 0.1
    done
    kill -KILL -- "-$DEVNET_PID" 2>/dev/null || true
    printf ' stopped.\n'
  fi
  if [ -n "${RUN_TMP:-}" ]; then rm -rf "$RUN_TMP"; fi
  if [ "$rc" -eq 0 ]; then
    printf '\n%sAll %s steps passed.%s Everything this run wrote is in %s\n' "$G" "$TOTAL" "$Z" "$WORK"
  else
    printf '\n%sThe run did not finish (exit status %s).%s What it wrote so far is in %s\n' "$R" "$rc" "$Z" "$WORK" >&2
  fi
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# =============================================================================
# SETUP: a work folder, two wallets, a private chain
# =============================================================================
if [ -e "$WORK" ]; then
  [ -f "$WORK/.singular-demo" ] || die "$WORK exists and is not a previous demo run; remove it or set WORK=another-folder"
  rm -rf "$WORK"
fi
mkdir -m 700 -p "$WORK/receipts" "$WORK/bundles" "$WORK/witnesses"
touch "$WORK/.singular-demo"
cd "$WORK"
BLUEPRINT=$KIT/share/plutus.json
SLOT_MS=$(jq -r '.slotLength * 1000 | round' "$KIT/share/genesis/shelley-genesis.json")

printf '%sSingular %s — Demo 1 on a private chain%s\n' "$B" "$(sed -n '1p' "$KIT/VERSION" | cut -d' ' -f2)" "$Z"
printf '  kit:        %s\n' "$KIT"
printf '  this run:   %s   (vaults, receipts, bundles; the whole run is kept there)\n' "$WORK"

#| Alice and Bob each need a wallet. A wallet here is a "vault": one encrypted file
#| that holds the wallet's signing key, locked with a passphrase. No key is ever
#| stored in the clear. Each passphrase sits in a small text file, and the program
#| reads it from "file descriptor 3" (--passphrase-fd 3, fed by "3< file" in the
#| shell), so nothing is typed and nothing appears on the command line.
#| The chain is a private test chain ("network magic" 42), nothing to do with a public one.
section "Setup 1 — two wallets"
printf '%s\n' "alice's passphrase" > alice.passphrase
printf '%s\n' "bob's passphrase"   > bob.passphrase
chmod 600 alice.passphrase bob.passphrase
cmd "singular wallet create --vault alice.vault --network-magic 42 --passphrase-fd 3   (passphrase: 3< alice.passphrase)"
capture receipts/00-alice-wallet.txt 0 singular wallet create --vault alice.vault --network-magic 42 --passphrase-fd 3 3< alice.passphrase
cmd "singular wallet create --vault bob.vault --network-magic 42 --passphrase-fd 3   (passphrase: 3< bob.passphrase)"
capture receipts/00-bob-wallet.txt 0 singular wallet create --vault bob.vault --network-magic 42 --passphrase-fd 3 3< bob.passphrase

#| A wallet's address is public: it is where money can be sent. Reading it opens the
#| vault with the passphrase, so this is also the check that the vault works.
why
cmd "singular wallet address --vault alice.vault --network-magic 42 --passphrase-fd 3"
ALICE_ADDR=$(singular wallet address --vault alice.vault --network-magic 42 --passphrase-fd 3 3< alice.passphrase)
cmd "singular wallet address --vault bob.vault --network-magic 42 --passphrase-fd 3"
BOB_ADDR=$(singular wallet address --vault bob.vault --network-magic 42 --passphrase-fd 3 3< bob.passphrase)
more "Alice: $ALICE_ADDR" "Bob:   $BOB_ADDR"

if [ "$DEVNET_MODE" = own ]; then
  #| The devnet is a private Cardano chain that lives only on this computer: a real
  #| Cardano node plus a small web API in front of it (the "provider") that the
  #| programs below talk to. It is told to give each of the two wallets 6 coins
  #| of 2000 ada ("ADDRESS:6:2000000000" = 6 outputs of 2 000 000 000 lovelace), and
  #| it never sees a key. It prints one line of settings when it is ready, then keeps
  #| running until this script stops it. This takes about half a minute.
  section "Setup 2 — start the private chain"
  RUN_TMP=$(mktemp -d /tmp/singular-demo.XXXXXX)      # short path: the node's socket path has a length limit
  export TMPDIR=$RUN_TMP
  cmd "devnet --fund-address ALICE:6:2000000000 --fund-address BOB:6:2000000000 > devnet.json   (keeps running)"
  setsid devnet --fund-address "$ALICE_ADDR:6:2000000000" --fund-address "$BOB_ADDR:6:2000000000" > devnet.json 2> devnet.log &
  DEVNET_PID=$!
  for _ in $(seq 1 180); do
    jq -e .providerUrl devnet.json > /dev/null 2>&1 && break
    kill -0 "$DEVNET_PID" 2>/dev/null || { cat devnet.log >&2; die "the devnet exited before it was ready (devnet.log above)"; }
    sleep 1
  done
  jq -e .providerUrl devnet.json > /dev/null 2>&1 || die "the devnet did not become ready within 3 minutes"
else
  #| You chose to run the chain yourself, so this script cannot start it. Open a second
  #| terminal and type the command printed below (it is the same command the script
  #| would run); this script continues by itself when the chain has printed its settings.
  section "Setup 2 — start the private chain in your second terminal"
  printf '\n  %sIn the other terminal, type:%s\n\n' "$B" "$Z"
  printf '    TMPDIR=/tmp %s/bin/devnet --fund-address %s:6:2000000000 --fund-address %s:6:2000000000 > %s/devnet.json\n' \
    "$KIT" "$ALICE_ADDR" "$BOB_ADDR" "$WORK"
  printf '\n  waiting for it…'
  for _ in $(seq 1 600); do
    jq -e .providerUrl devnet.json > /dev/null 2>&1 && break
    sleep 1
  done
  jq -e .providerUrl devnet.json > /dev/null 2>&1 || die "no chain settings appeared in $WORK/devnet.json within 10 minutes"
  printf ' found.\n'
fi

#| The chain printed one line of settings (devnet.json; the first line is copied to
#| settings.json). "providerUrl" is the web API that answers every read and accepts
#| every transaction; "networkTimeDirectory" holds the chain's clock data (which slot
#| happens at which moment), which the programs need to turn a deadline into a slot;
#| "networkMagic" is the chain's number, 42.
why
cmd "jq . settings.json"
head -n 1 devnet.json > settings.json
KOIOS_URL=$(jq -r .providerUrl settings.json)
TIME_DIR=$(jq -r .networkTimeDirectory settings.json)
facts settings.json 'row("provider URL"; .providerUrl), row("network magic"; .networkMagic), row("chain clock data"; .networkTimeDirectory | split("/")[-3:] | join("/") | "…/" + .)'
until tip_slot > /dev/null 2>&1; do sleep 1; done
more "The chain is up and producing blocks (one every ${SLOT_MS} milliseconds)."
PROVIDER=(--koios-url "$KOIOS_URL" --network-time "$TIME_DIR" --network-magic 42)
ALICE=(--vault alice.vault --passphrase-fd 3)

# =============================================================================
# THE 16 STEPS
# =============================================================================

#| A registry is created from one unspent coin, the "seed": whoever holds that coin
#| can create exactly one registry from it, which is what makes its identity unique.
#| The command picks one of Alice's coins as the seed by itself. The registry's name is
#| its "state token". One command opens Alice's vault, builds the transactions that publish
#| the registry's scripts and its first state, signs them, sends them, and prints a receipt
#| when everything has landed. The windows are short on purpose, so the waits later last
#| minutes: @PROCESS_S@ seconds for the registry to process a request, @RETRACT_S@ more for its owner to take it back.
step 1 "create the registry (Alice)"
cmd "open-datum create --process-time $PROCESS_TIME_MS --retract-time $RETRACT_TIME_MS --state-dir reg --blueprint plutus.json <provider> <alice>"
capture receipts/01-create.json 0 open-datum create --process-time "$PROCESS_TIME_MS" --retract-time "$RETRACT_TIME_MS" --state-dir reg --blueprint "$BLUEPRINT" "${PROVIDER[@]}" "${ALICE[@]}" 3< alice.passphrase
STATE_TOKEN=$(jq -r .stateToken receipts/01-create.json)
facts receipts/01-create.json 'row("outcome"; .outcome), row("seed (a coin of Alice)"; .seed | sr), row("state token (its name)"; .stateToken | split(".") | (.[0] | s) + " . " + (.[1] | s)), row("transactions landed"; .transactions | length), row("processing window"; "\(.processTime / 1000) s"), row("retract window"; "\(.retractTime / 1000) s"), row("root (empty registry)"; .root | s)'
saved receipts/01-create.json
REGISTRY=(--state-dir reg --blueprint "$BLUEPRINT" --state-token "$STATE_TOKEN")
more "" "From here on, three groups of options repeat on every command, so they are abbreviated:" \
  "  <provider> = --koios-url URL --network-time DIR --network-magic 42   (which chain to talk to)" \
  "  <registry> = --state-dir reg --blueprint plutus.json --state-token TOKEN   (which registry: its journal" \
  "               folder reg, the compiled contracts, and the name printed above)" \
  "  <alice>    = --vault alice.vault --passphrase-fd 3   (and 3< alice.passphrase)"
pause_if_asked

#| The registry describes itself: which registry this is, which release of Singular runs it,
#| its rules and what it holds now. The create receipt contained this exact command (the
#| field "describeCommand"), and this is that command, run as printed. The page is read
#| from the chain's provider, so it is what the chain says and not a signed statement.
step 2 "read the registry's page"
cmd "singular registry describe <registry> <provider>      (the \"describeCommand\" of the create receipt)"
capture receipts/02-describe.txt 0 bash -c "$(jq -r .describeCommand receipts/01-create.json)"
grep -E '^(registry|release|rules|state):|^  (stateToken|version|releaseUrl|processTime|retractTime|maxKeyBytes|root|activeKeys|terminalKeys|pendingRequests):' receipts/02-describe.txt | shorten | sed 's/^/    /'
saved receipts/02-describe.txt

#| Alice adds a key. She books "alice" with a first piece of data (the payload: here
#| the number 42, written as Plutus data in JSON). The booking locks her deposit of
#| 2 ada in a request at the registry. It does not change the registry yet: the request is
#| PENDING until somebody folds it, and the receipt names the deadline for that, the
#| "fold deadline". Alice's wallet becomes the key's controller, the only one who may change it.
step 3 "book the key \"alice\" (Alice)"
echo '{"constructor":0,"fields":[{"int":42}]}' > payload.json
cmd "open-datum insert --key alice --payload payload.json <registry> <provider> <alice>"
capture receipts/03-insert-alice.json 0 open-datum insert "${REGISTRY[@]}" --key alice --payload payload.json "${PROVIDER[@]}" "${ALICE[@]}" 3< alice.passphrase
facts receipts/03-insert-alice.json 'row("outcome"; .outcome), row("pending request"; .request | sr), row("key"; .keyText), row("deposit locked"; .envelope.fields[0].fields[5].int | ada), row("fold deadline"; "slot \(.foldDeadline.slot)")'
saved receipts/03-insert-alice.json
pause_if_asked

#| A "fold" moves pending requests into the registry for good. Anyone may do it, and
#| here Bob does, the external way: his command only names his address and a bundle file.
#| It builds the transactions, writes them into that file, signs nothing and sends nothing.
step 4 "fold it (Bob signs outside the program)"
cmd "open-datum fold <registry> <provider> --wallet-address BOB --bundle bundles/fold-insert.bundle      → exits 19"
capture receipts/04-fold-insert.json 19 open-datum fold "${REGISTRY[@]}" "${PROVIDER[@]}" --wallet-address "$BOB_ADDR" --bundle bundles/fold-insert.bundle
facts receipts/04-fold-insert.json 'row("outcome"; .outcome), (.expected.settled[] | row("would settle"; "\(.key | unhex) (\(.edge)), request \(.request | sr)")), row("new root would be"; .expected.root | s), row("time left to fold"; "\(.expected.remainingMs / 1000 | floor) s")'
saved receipts/04-fold-insert.json
bob_signs_and_sends fold-insert 04
pause_if_asked

#| Reading is free and needs no key and no wallet. "inspect" asks the chain for the key's
#| state and prints what it found: the key is now ACTIVE, with its payload, its owner and
#| the deposit that stays locked with it.
step 5 "read the key back"
cmd "open-datum inspect --key alice <registry> <provider>"
capture receipts/05-inspect.json 0 open-datum inspect "${REGISTRY[@]}" --key alice "${PROVIDER[@]}"
facts receipts/05-inspect.json 'row("key"; .keyText), row("state"; .leaf), row("payload"; .applicationOutput.payload | tojson), row("deposit"; .applicationOutput.deposit | ada), row("held in output"; .applicationOutput.output | sr), row("registry root"; .root | s)'
saved receipts/05-inspect.json
pause_if_asked

#| Alice, as the key's controller, replaces the payload with 43. Only she may; nobody
#| else's signature would be accepted. An update is immediate (no booking, no fold), and
#| the registry's root does not change: the receipt shows the root before and after.
step 6 "change the data (Alice)"
echo '{"constructor":0,"fields":[{"int":43}]}' > payload-new.json
cmd "open-datum update --key alice --payload payload-new.json <registry> <provider> <alice>"
capture receipts/06-update.json 0 open-datum update "${REGISTRY[@]}" --key alice --payload payload-new.json "${PROVIDER[@]}" "${ALICE[@]}" 3< alice.passphrase
ROOT_BEFORE=$(jq -r .root receipts/05-inspect.json); ROOT_AFTER=$(jq -r .root receipts/06-update.json)
facts receipts/06-update.json 'row("outcome"; .outcome), row("new payload"; .payload | tojson)'
[ "$ROOT_BEFORE" = "$ROOT_AFTER" ] || die "the root moved on an update"
printf "    %-24s%s\n" "root before:" "${ROOT_BEFORE:0:12}…" "root after:" "${ROOT_AFTER:0:12}…  (the same, as it must be)"
saved receipts/06-update.json
pause_if_asked

#| The same read again: the payload is now 43, the owner and the deposit are unchanged.
step 7 "read the key back again"
cmd "open-datum inspect --key alice <registry> <provider>"
capture receipts/07-inspect.json 0 open-datum inspect "${REGISTRY[@]}" --key alice "${PROVIDER[@]}"
facts receipts/07-inspect.json 'row("state"; .leaf), row("payload"; .applicationOutput.payload | tojson), row("deposit"; .applicationOutput.deposit | ada), row("registry root"; .root | s)'
saved receipts/07-inspect.json
pause_if_asked

#| Removing a key is also two stages. Alice books the termination of "alice": the receipt
#| names the pending request, the live output the fold will release, and the deposit
#| that will come back to her.
step 8 "book the removal of the key (Alice)"
cmd "open-datum terminate --key alice <registry> <provider> <alice>"
capture receipts/08-terminate.json 0 open-datum terminate "${REGISTRY[@]}" --key alice "${PROVIDER[@]}" "${ALICE[@]}" 3< alice.passphrase
facts receipts/08-terminate.json 'row("outcome"; .outcome), row("pending request"; .request | sr), row("will release"; .released | sr), row("deposit to return"; .deposit | ada), row("fold deadline"; "slot \(.foldDeadline.slot)")'
saved receipts/08-terminate.json
pause_if_asked

#| Bob folds the termination, the external way again. When it lands, the key's token is
#| burned and the deposit goes back to Alice.
step 9 "fold the removal (Bob signs outside the program)"
cmd "open-datum fold <registry> <provider> --wallet-address BOB --bundle bundles/fold-terminate.bundle      → exits 19"
capture receipts/09-fold-terminate.json 19 open-datum fold "${REGISTRY[@]}" "${PROVIDER[@]}" --wallet-address "$BOB_ADDR" --bundle bundles/fold-terminate.bundle
facts receipts/09-fold-terminate.json 'row("outcome"; .outcome), (.expected.settled[] | row("would settle"; "\(.key | unhex) (\(.edge)), request \(.request | sr)")), row("time left to fold"; "\(.expected.remainingMs / 1000 | floor) s")'
saved receipts/09-fold-terminate.json
bob_signs_and_sends fold-terminate 09
pause_if_asked

#| Read it back: the key is now TERMINAL (gone for good, it can never be used again) and
#| nothing holds it any more.
step 10 "read the removed key"
cmd "open-datum inspect --key alice <registry> <provider>"
capture receipts/10-inspect.json 0 open-datum inspect "${REGISTRY[@]}" --key alice "${PROVIDER[@]}"
facts receipts/10-inspect.json 'row("state"; .leaf), row("holding"; .applicationOutput.absent // "?"), row("registry root"; .root | s)'
saved receipts/10-inspect.json
pause_if_asked

#| What if nobody folds a request? Alice books the key "late" and nobody touches it. A
#| request that stays pending past its two windows (processing, then retract) blocks the
#| registry, and the cure is a REJECT, which sends the deposit back to the owner. While
#| a window is still open the program refuses to build it, and says so; that refusal is
#| the first thing shown. Windows are judged by the chain's own latest block (its "tip"),
#| never by this computer's clock.
step 11 "a request nobody folded: wait out its windows, then reject it"
cmd "open-datum insert --key late --payload payload.json <registry> <provider> <alice>"
capture receipts/11a-insert-late.json 0 open-datum insert "${REGISTRY[@]}" --key late --payload payload.json "${PROVIDER[@]}" "${ALICE[@]}" 3< alice.passphrase
facts receipts/11a-insert-late.json 'row("pending request"; .request | sr), row("fold deadline"; "slot \(.foldDeadline.slot)")'
cmd "singular registry reject <registry> <provider> --wallet-address BOB --bundle bundles/reject.bundle      → refused for now"
capture receipts/11b-reject-too-early.json 10 singular registry reject "${REGISTRY[@]}" "${PROVIDER[@]}" --wallet-address "$BOB_ADDR" --bundle bundles/reject.bundle
facts receipts/11b-reject-too-early.json 'row("outcome"; .outcome), (.pendingRequests[] | row("still in a window"; "\(.request | sr), retract window closes at slot \(.retractEndsSlot)")), row("chain tip now"; "slot \(.tipSlot)")'
saved receipts/11b-reject-too-early.json
more "Refused, and nothing was built: the request is still inside its windows. So we wait for the chain" \
     "tip to pass the end of the retract window (the processing window plus the retract window, $(span $(( PROCESS_TIME_MS + RETRACT_TIME_MS ))))."
wait_for_slot "$(jq -r '.pendingRequests[0].retractEndsSlot' receipts/11b-reject-too-early.json)" "waiting for the retract window to close"

#| Both windows are over. Bob asks again, the external way (anyone may reject), and this time
#| the program builds the transaction: it returns the request's locked value to its owner, Alice.
why
cmd "singular registry reject <registry> <provider> --wallet-address BOB --bundle bundles/reject.bundle      → exits 19"
capture receipts/11c-reject.json 19 singular registry reject "${REGISTRY[@]}" "${PROVIDER[@]}" --wallet-address "$BOB_ADDR" --bundle bundles/reject.bundle
facts receipts/11c-reject.json 'row("outcome"; .outcome), (.expected.rejected[] | row("rejects"; "\(.key | unhex), request \(.request | sr)"), row("locked value"; "\(.locked.lovelace | ada) and the request token"), row("refund to"; "\(.returned.recipient | .[0:20])… (Alice), \(.returned.lovelace | ada)")), row("registry root"; "unchanged: \(.expected.root | s)")'
saved receipts/11c-reject.json
bob_signs_and_sends reject 11
pause_if_asked

#| The registry takes requests again. This time Bob adds a key, with his own wallet and the
#| external flow from the start: his command names his address and a bundle file, and the
#| bundle holds the booking.
step 12 "book the key \"bob\" (Bob signs outside the program)"
cmd "open-datum insert --key bob --payload payload.json <registry> <provider> --wallet-address BOB --bundle bundles/insert-bob.bundle      → exits 19"
capture receipts/12-insert-bob.json 19 open-datum insert "${REGISTRY[@]}" --key bob --payload payload.json "${PROVIDER[@]}" --wallet-address "$BOB_ADDR" --bundle bundles/insert-bob.bundle
facts receipts/12-insert-bob.json 'row("outcome"; .outcome), row("pending request"; .expected.request | sr), row("fold deadline"; "slot \(.expected.foldDeadline.slot)")'
saved receipts/12-insert-bob.json
bob_signs_and_sends insert-bob 12
pause_if_asked

#| Alice folds Bob's request. Here the fold is a single command, because it is her vault
#| that signs and sends it, and it prints its receipt when it has landed.
step 13 "fold Bob's key (Alice, vault in one command)"
cmd "open-datum fold <registry> <provider> <alice>"
capture receipts/13-fold-bob.json 0 open-datum fold "${REGISTRY[@]}" "${PROVIDER[@]}" "${ALICE[@]}" 3< alice.passphrase
facts receipts/13-fold-bob.json 'row("outcome"; .outcome), (.settled[] | row("settled"; "\(.key | unhex) (\(.edge)), request \(.request | sr)")), row("new root"; .root | s)'
saved receipts/13-fold-bob.json
pause_if_asked

#| The other way out of a pending request is for its owner to take it back, which is called a
#| RECLAIM, and it is only allowed in the retract window: after the registry's processing
#| window has ended and before the retract window ends. Alice books "carol", and nobody folds
#| it. Reclaiming straight away is refused (the processing window is still open); once the chain
#| tip passes the processing deadline, Alice can take the request back.
step 14 "take back a request: wait for the retract window, then reclaim it"
cmd "open-datum insert --key carol --payload payload.json <registry> <provider> <alice>"
capture receipts/14a-insert-carol.json 0 open-datum insert "${REGISTRY[@]}" --key carol --payload payload.json "${PROVIDER[@]}" "${ALICE[@]}" 3< alice.passphrase
CAROL_REQUEST=$(jq -r .request receipts/14a-insert-carol.json)
CAROL_OPENS=$(jq -r .foldDeadline.slot receipts/14a-insert-carol.json)
facts receipts/14a-insert-carol.json 'row("pending request"; .request | sr), row("retract window opens"; "after slot \(.foldDeadline.slot)")'
cmd "singular registry reclaim --request $(printf %s "${CAROL_REQUEST%%#*}" | shorten)#0 <registry> <provider> <alice>      → refused for now"
capture receipts/14b-reclaim-too-early.json 10 singular registry reclaim "${REGISTRY[@]}" --request "$CAROL_REQUEST" "${PROVIDER[@]}" "${ALICE[@]}" 3< alice.passphrase
facts receipts/14b-reclaim-too-early.json 'row("outcome"; .outcome), row("reason"; .reason | gsub("[0-9]{13} ms"; "…"))'
saved receipts/14b-reclaim-too-early.json
wait_for_slot "$CAROL_OPENS" "waiting for the processing window to end (the retract window then opens)"

#| The window is open: Alice's wallet, which owns the request, takes it back with one
#| command. The receipt names the request, the transaction that retracted it, and the money
#| it returned to her.
why
cmd "singular registry reclaim --request $(printf %s "${CAROL_REQUEST%%#*}" | shorten)#0 <registry> <provider> <alice>"
capture receipts/14c-reclaim.json 0 singular registry reclaim "${REGISTRY[@]}" --request "$CAROL_REQUEST" "${PROVIDER[@]}" "${ALICE[@]}" 3< alice.passphrase
facts receipts/14c-reclaim.json 'row("outcome"; .outcome), row("reclaimed request"; .request | sr), row("returned to"; "\(.returned.recipient | .[0:20])… (Alice), \(.returned.lovelace | ada)"), row("window"; "slots \(.processingEndsSlot) to \(.retractEndsSlot); chain tip was \(.tipSlot)")'
saved receipts/14c-reclaim.json
pause_if_asked

#| The reclaimed request no longer blocks anything, so Alice books one more key, "dave".
step 15 "book the key \"dave\" (Alice)"
cmd "open-datum insert --key dave --payload payload.json <registry> <provider> <alice>"
capture receipts/15-insert-dave.json 0 open-datum insert "${REGISTRY[@]}" --key dave --payload payload.json "${PROVIDER[@]}" "${ALICE[@]}" 3< alice.passphrase
facts receipts/15-insert-dave.json 'row("outcome"; .outcome), row("pending request"; .request | sr), row("fold deadline"; "slot \(.foldDeadline.slot)")'
saved receipts/15-insert-dave.json
pause_if_asked

#| Bob folds "dave", external signing as before. Afterwards an independent read asks the
#| chain for the key and finds it ACTIVE: the last proof that the whole journey worked.
step 16 "fold \"dave\" (Bob signs outside the program), then read it"
cmd "open-datum fold <registry> <provider> --wallet-address BOB --bundle bundles/fold-dave.bundle      → exits 19"
capture receipts/16a-fold-dave.json 19 open-datum fold "${REGISTRY[@]}" "${PROVIDER[@]}" --wallet-address "$BOB_ADDR" --bundle bundles/fold-dave.bundle
facts receipts/16a-fold-dave.json 'row("outcome"; .outcome), (.expected.settled[] | row("would settle"; "\(.key | unhex) (\(.edge)), request \(.request | sr)")), row("time left to fold"; "\(.expected.remainingMs / 1000 | floor) s")'
saved receipts/16a-fold-dave.json
bob_signs_and_sends fold-dave 16
cmd "open-datum inspect --key dave <registry> <provider>"
capture receipts/16b-inspect-dave.json 0 open-datum inspect "${REGISTRY[@]}" --key dave "${PROVIDER[@]}"
facts receipts/16b-inspect-dave.json 'row("key"; .keyText), row("state"; .leaf), row("payload"; .applicationOutput.payload | tojson), row("registry root"; .root | s)'
[ "$(jq -r .leaf receipts/16b-inspect-dave.json)" = active ] || die "dave is not active"
saved receipts/16b-inspect-dave.json
