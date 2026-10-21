#!/usr/bin/env bash
# The receipts a whole run of the two-window scenario leaves in Alice's and Bob's folders, and what each must say.
# The scenario test (Killercoda's windows) and the kit's terminal test (drive.sh) both judge their run with it.
#   check-receipts.sh RUN_DIR    needs jq; exit 0 only if every receipt holds
set -u
cd "${1:?usage: check-receipts.sh RUN_DIR}" || exit 1
fail=0
check() { if jq -e "$2" "$1" >/dev/null 2>&1; then echo "ok    $1  $2"; else
  echo "FAIL  $1  $2"
  fail=1
fi; }
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
exit $fail
