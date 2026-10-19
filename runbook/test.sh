#!/usr/bin/env bash
# Runs every "bash" block of the step files, in order, in one shell, against a fresh private devnet,
# then checks the receipts. Run it inside the nix shell:
#   nix develop path:. --command bash runbook/test.sh
# It takes about ten minutes: the reject and the reclaim wait for the chain's own clock.
set -u
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d /tmp/rb-XXXXXX)
for f in "$here"/s*.md; do awk '/^```bash$/{on=1; next} /^```/{on=0} on' "$f"; done > "$work/blocks.sh"
{
  printf 'export HOME=%q TMPDIR=%q PASSDIR=%q LOGFILE=%q\nmkdir -p "$HOME" "$TMPDIR"\n' "$work/home" "$work/tmp" "$work/pass" "$work/log.txt"
  # The pasted blocks ask for passphrases at a prompt. The test cannot type, so these two
  # functions answer for it: when a command names a vault, the passphrase comes from a file.
  printf 'mkdir -p %q; printf "%%s\\n" "alice test" > %q/alice; printf "%%s\\n" "bob test" > %q/bob\n' "$work/pass" "$work/pass" "$work/pass"
  cat <<'WRAP'
_with_pass() { local prog=$1 a v=""; shift; for a in "$@"; do case "$a" in *.vault) v=$(basename "$a" .vault);; esac; done
  if [ -n "$v" ]; then command "$prog" "$@" --passphrase-fd 3 3< "$PASSDIR/$v"; else command "$prog" "$@"; fi; }
singular() { _with_pass singular "$@"; }
open-datum() { _with_pass open-datum "$@"; }
WRAP
  cat "$work/blocks.sh"
  cat <<'CHECKS'
echo "=== checks"
fail=0
check() { if jq -e "$2" "$1" >/dev/null 2>&1; then echo "ok    $1  $2"; else echo "FAIL  $1  $2"; fail=1; fi; }
check receipts/01b-create.json '.outcome=="success"'
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
if grep -qE 'jq: error|command not found|curl: \\(' "$LOGFILE"; then echo "FAIL  an error line in the log"; fail=1; else echo "ok    no jq, curl or command error in the log"; fi
if pgrep -f "$TMPDIR" >/dev/null; then echo "FAIL  a process still uses $TMPDIR"; fail=1; else echo "ok    nothing left running"; fi
echo "RESULT: $([ $fail = 0 ] && echo PASS || echo FAIL)"
exit $fail
CHECKS
} > "$work/run.sh"
echo "running $(wc -l < "$work/blocks.sh") lines of pasted blocks; log in $work/log.txt"
bash "$work/run.sh" > "$work/log.txt" 2>&1
rc=$?
tail -22 "$work/log.txt"
echo "log: $work/log.txt"
exit $rc
