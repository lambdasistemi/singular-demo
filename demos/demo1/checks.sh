# shellcheck shell=bash
# shellcheck disable=SC2016 # jq programs: the $ names are jq's, not the shell's
echo "=== checks"
fail=0
check() { # FILE [jq options...] FILTER
  local file=$1 filter=${!#}
  set -- "${@:2:$#-2}"
  if jq -e "$@" "$filter" "$file" >/dev/null 2>&1; then echo "ok    $file  $filter"; else
    echo "FAIL  $file  $filter"
    fail=1
  fi
}
check receipts/01-create.json '.outcome=="success"'
check receipts/02-describe.json '.outcome=="success" and .rules.processTime>0'
check receipts/02-describe-bob.json '.outcome=="success" and .rules.processTime>0'
# the registry is named by its address alone: the one create printed is in Alice's file and, handed over, in Bob's;
# neither file has a state token; both pages name the same registry
registry=$(jq -r .registry receipts/01-create.json)
check receipts/01-create.json '.registry|test("^singular_devnet1[0-9a-z]+$")'
check alice.json --arg r "$registry" '.registry==$r and has("network-magic") and (has("state-token")|not)'
check bob.json --arg r "$registry" '.registry==$r and has("network-magic") and (has("state-token")|not)'
if [ "$(cat registry.address)" = "$registry" ]; then echo "ok    registry.address holds the address and nothing else"; else
  echo "FAIL  registry.address is not the address create printed"
  fail=1
fi
# what the page printed of Bob's file before the address was handed over names no registry, and after it the address
block() { awk -v b="@@ BLOCK $1 $2" '$0 == b {p = 1; next} /^@@ BLOCK /{p = 0} p' "$LOGFILE"; }
if block s02-describe.md 4 | jq -e 'has("state-dir") and (has("registry") | not)' >/dev/null 2>&1 &&
  block s02-describe.md 5 | jq -e --arg r "$registry" '.registry == $r' >/dev/null 2>&1; then
  echo "ok    Bob's file named no registry before the address was handed over, and the address after"
else
  echo "FAIL  Bob's file before and after the hand-over"
  fail=1
fi
if jq -e -s '.[0].registry.address == .[1].registry.address' receipts/02-describe.json receipts/02-describe-bob.json >/dev/null 2>&1; then
  echo "ok    Alice's page and Bob's page name the same registry"
else
  echo "FAIL  Alice's page and Bob's page do not name the same registry"
  fail=1
fi
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
