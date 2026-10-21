# shellcheck shell=bash
echo "=== checks"
fail=0
check() { if jq -e "$2" "$1" >/dev/null 2>&1; then echo "ok    $1  $2"; else
  echo "FAIL  $1  $2"
  fail=1
fi; }
check receipts/01-create.json '.outcome=="success"'
check receipts/02-describe.json '.outcome=="success" and .rules.processTime>0'
check receipts/03-insert-alice.json '.outcome=="success"'
check receipts/04-fold-insert.json '.outcome=="waiting-for-signatures"'
check receipts/04-fold-insert.submitted.json '(.submissions|length)>=1'
check receipts/05-inspect.json '.leaf=="active"'
check receipts/06-update.json '.outcome=="success"'
check receipts/08-terminate.json '.outcome=="success"'
check receipts/09-fold-terminate.json '.outcome=="waiting-for-signatures"'
check receipts/10-inspect.json '.leaf=="terminal"'
check receipts/11b-reject-too-early.json '.outcome=="client-refusal"'
check receipts/11d-reject.json '.outcome=="waiting-for-signatures"'
check receipts/12-insert-bob.json '.outcome=="waiting-for-signatures"'
check receipts/13-fold-bob.json '.outcome=="success"'
check receipts/14b-reclaim-too-early.json '.outcome=="client-refusal"'
check receipts/14c-reclaim.json '.outcome=="success"'
check receipts/15-insert-dave.json '.outcome=="success"'
check receipts/16b-inspect-dave.json '.leaf=="active"'
if grep -qE 'jq: error|command not found|curl: [(]' "$LOGFILE"; then
  echo "FAIL  an error line in the log"
  fail=1
else echo "ok    no jq, curl or command error in the log"; fi
if [ -n "${TMPDIR:-}" ] && command -v pgrep >/dev/null && pgrep -f "$TMPDIR" >/dev/null; then
  echo "FAIL  a process still uses $TMPDIR"
  fail=1
else echo "ok    nothing left running"; fi
echo "RESULT: $([ $fail = 0 ] && echo PASS || echo FAIL)"
exit $fail
