#!/usr/bin/env bash
# Check observed transactions, their public references and the answers of the key reads after the complete tutorial.
# shellcheck disable=SC2016
set -euo pipefail
cd "${1:?usage: check-receipts.sh RUN_DIR}"
check() {
  jq -e "$2" "$1" >/dev/null
  printf 'ok    %s\n' "$1"
}
observed='(.submissions | length) > 0 and all(.submissions[]; .confirmations > 0 and (.identity | test("^[0-9a-f]{64}$")) and .chainPoint.slot >= 0 and (.outputs | length) > 0)'
check carol/receipts/01-create.json '.outcome == "success" and (.stateToken | test("^[0-9a-f]{56}\\.[0-9a-f]{64}$"))'
token=$(jq -er .stateToken carol/receipts/01-create.json)
[ "$(cat registry.token)" = "$token" ]
for who in alice bob; do jq -e --arg t "$token" '.["state-token"] == $t and .["state-dir"] != null' "$who/$who.json" >/dev/null; done
for file in carol/receipts/01-create alice/receipts/03-insert-alice bob/receipts/04-fold-insert alice/receipts/06-update alice/receipts/08-terminate bob/receipts/09-fold-terminate alice/receipts/11a-insert-late bob/receipts/11d-cleanup alice/receipts/13-fold-bob alice/receipts/14a-insert-unfolded alice/receipts/14c-reclaim alice/receipts/15-insert-dave; do
  check "$file.json" ".outcome == \"success\" and ($observed)"
  jq -e --arg t "$token" '.stateToken == $t' "$file.json" >/dev/null
done
check alice/receipts/03-insert-alice.json '.deposit == 3000000 and (.pending | type == "string")'
check alice/receipts/06-update.json '.holding | test("^[0-9a-f]{64}#[0-9]+$")'
check alice/receipts/08-terminate.json '.treasuryDonation == 3000000'
for scene in 12-insert-bob 16a-fold-dave; do
  check "bob/receipts/$scene.json" '.outcome == "waiting-for-signatures"'
  jq -e --arg t "$token" '.expected.stateToken == $t' "bob/receipts/$scene.json" >/dev/null
  check "bob/receipts/$scene.submitted.json" ".outcome == \"success\" and ($observed)"
done
test -s bob/bundles/insert-bob.bundle
test -s bob/bundles/fold-dave.bundle
for pair in 'insert-bob 12-insert-bob' 'fold-dave 16a-fold-dave'; do
  read -r bundle scene <<<"$pair"
  jq -e -n --slurpfile b "bob/bundles/$bundle.bundle" --slurpfile r "bob/receipts/$scene.submitted.json" '($b[0].transactions | map(.identity) | sort) == ($r[0].submissions | map(.identity) | sort)' >/dev/null
done
# The folds found their requests on the chain. Each folded exactly the request the story had pending at that
# moment, skipped only the application's configuration output (it holds an approval token but is not a request)
# and left nothing foldable behind.
hex() { printf %s "$1" | od -An -tx1 | tr -d ' \n'; }
config=$(jq -er '.applicationPolicy as $a | [.submissions[].outputs[] | select(any(.assets[]; .policy == $a)) | .output]
  | if length == 1 then .[0] else error("expected one configuration output") end' carol/receipts/01-create.json)
fold_of() { # FOLD_RECEIPT BOOKING_RECEIPT KIND KEY: the fold's accounting (a bundle receipt keeps it under .expected)
  jq -e -n --slurpfile f "$1" --slurpfile b "$2" --arg kind "$3" --arg key "$(hex "$4")" --arg c "$config" '
    ($f[0] | .expected // .) as $r | ($b[0] | .expected.pending // .pending) as $p
    | $r.folded == [{key: $key, kind: $kind, pending: $p}] and $r.left == 0
      and ($r.skipped | map(.reference)) == [$c] and all($r.skipped[]; .reason | test("not accepted"))' >/dev/null
  printf 'ok    %s: folded the %s of %s, skipped the configuration output, left 0\n' "$1" "$3" "$4"
}
fold_of bob/receipts/04-fold-insert.json alice/receipts/03-insert-alice.json registration alice
fold_of bob/receipts/09-fold-terminate.json alice/receipts/08-terminate.json termination alice
fold_of alice/receipts/13-fold-bob.json bob/receipts/12-insert-bob.json registration bob
fold_of bob/receipts/16a-fold-dave.json alice/receipts/15-insert-dave.json registration dave
for pair in 'alice/receipts/11a-insert-late.json bob/receipts/11d-cleanup.json' 'alice/receipts/14a-insert-unfolded.json alice/receipts/14c-reclaim.json'; do
  read -r booking refund <<<"$pair"
  jq -e -n --slurpfile b "$booking" --slurpfile r "$refund" '$r[0].pending == $b[0].pending and $r[0].returned.recipient == $b[0].refundAddress and $r[0].returned.lovelace >= $b[0].deposit + $b[0].tip' >/dev/null
done
# The reads: each answer is the state the receipts say the key is in at that point of the story.
registry=$(jq -er .registry carol/receipts/01-create.json)
read_of() { # FILE COMMAND KEY ANSWER: who answered, about which registry and key, and the answer
  jq -e --arg r "$registry" --arg p "${token%%.*}" --arg c "$2" --arg k "$(hex "$3")" --arg a "$4" \
    '.registry == $r and .application["state-policy"] == $p and .command == $c and .keyHex == $k and .answer == $a' "$1" >/dev/null
  printf 'ok    %s: %s\n' "$1" "$4"
}
# after the fold: live, in the fold's transaction, with Alice's payload and deposit
read_of alice/receipts/05-read-alice.json inspect alice live
jq -e -n --slurpfile read alice/receipts/05-read-alice.json --slurpfile fold bob/receipts/04-fold-insert.json --arg t "$token" '
  $read[0] | .payload == {answer: 42} and .deposit == 3000000 and .control.registry == $t
  and (.outputRef | split("#")[0]) == ($fold[0].stateOutput | split("#")[0])' >/dev/null
# after the update: live, in the holding the update created, with the new payload
read_of alice/receipts/07-read-alice.json inspect alice live
jq -e -n --slurpfile read alice/receipts/07-read-alice.json --slurpfile first alice/receipts/05-read-alice.json --slurpfile update alice/receipts/06-update.json '
  $read[0] | .payload == {answer: 43} and .deposit == 3000000 and .outputRef == $update[0].holding and .outputRef != $first[0].outputRef' >/dev/null
# after the termination booking: pending, at the request Alice booked
read_of bob/receipts/09-read-alice.json inspect alice pending-termination
jq -e -n --slurpfile read bob/receipts/09-read-alice.json --slurpfile booking alice/receipts/08-terminate.json '
  $read[0].outputRef == $booking[0].pending' >/dev/null
# after the termination fold: terminal, and a key nobody booked never registered, both from the state the fold wrote
read_of alice/receipts/10-read-alice.json 'registry inspect' alice terminal
read_of alice/receipts/10-read-nobody.json 'registry inspect' nobody never-registered
for file in alice/receipts/10-read-alice.json alice/receipts/10-read-nobody.json; do
  jq -e -n --slurpfile read "$file" --slurpfile fold bob/receipts/09-fold-terminate.json '
    $read[0].stateOutput == $fold[0].stateOutput and $read[0].root == $fold[0].root' >/dev/null
done
printf 'All lifecycle receipts and reads passed.\n'
