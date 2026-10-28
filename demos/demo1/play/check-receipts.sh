#!/usr/bin/env bash
# Check observed transactions and their public references after the complete tutorial.
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
check bob/receipts/04-fold-insert.json '.folded | length == 1'
check alice/receipts/06-update.json '.holding | test("^[0-9a-f]{64}#[0-9]+$")'
check alice/receipts/08-terminate.json '.treasuryDonation == 3000000'
check bob/receipts/09-fold-terminate.json '.folded | length == 1'
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
jq -e -n --slurpfile booking bob/receipts/12-insert-bob.json --slurpfile fold alice/receipts/13-fold-bob.json '$fold[0].folded[0].pending == $booking[0].expected.pending' >/dev/null
jq -e -n --slurpfile booking alice/receipts/15-insert-dave.json --slurpfile fold bob/receipts/16a-fold-dave.json '$fold[0].expected.folded[0].pending == $booking[0].pending' >/dev/null
jq -e -n --slurpfile booking alice/receipts/03-insert-alice.json --slurpfile fold bob/receipts/04-fold-insert.json '$fold[0].folded[0].pending == $booking[0].pending' >/dev/null
jq -e -n --slurpfile booking alice/receipts/08-terminate.json --slurpfile fold bob/receipts/09-fold-terminate.json '$fold[0].folded[0].pending == $booking[0].pending' >/dev/null
for pair in 'alice/receipts/11a-insert-late.json bob/receipts/11d-cleanup.json' 'alice/receipts/14a-insert-unfolded.json alice/receipts/14c-reclaim.json'; do
  read -r booking refund <<<"$pair"
  jq -e -n --slurpfile b "$booking" --slurpfile r "$refund" '$r[0].pending == $b[0].pending and $r[0].returned.recipient == $b[0].refundAddress and $r[0].returned.lovelace >= $b[0].deposit + $b[0].tip' >/dev/null
done
printf 'All lifecycle receipts passed.\n'
