#!/usr/bin/env bash
# Runs every "bash" block of the step files, in order, in one shell, against a fresh private devnet,
# then checks the receipts. Run it inside the nix shell:
#   nix develop path:. --command bash runbook/test.sh
# or, with no Nix, against the unpacked Ubuntu kit (for example inside a clean ubuntu:24.04 container):
#   KIT_DIR=/path/to/singular-demo-VERSION-x86_64-linux bash runbook/test.sh
# It takes about ten minutes: the reject and the reclaim wait for the chain's own clock.
set -u
here=$(cd "$(dirname "$0")" && pwd)
bash "$here/lint.sh" "$here"/s*.md || exit 1
work=$(mktemp -d /tmp/rb-XXXXXX)
# A marker line comes before each block, so record.js can pair every command with what it printed.
for f in "$here"/s*.md; do awk -v f="$(basename "$f")" '/^```bash$/{on=1; n++; print "echo \"@@ BLOCK " f " " n "\""; next} /^```/{on=0} on' "$f"; done >"$work/blocks.sh"
# shellcheck disable=SC2016 # this writes the text of a script: its $ expansions happen when that script runs
{
  printf 'export HOME=%q TMPDIR=%q PASSDIR=%q LOGFILE=%q\nmkdir -p "$HOME" "$TMPDIR"\n' "$work/home" "$work/tmp" "$work/pass" "$work/log.txt"
  # With KIT_DIR set (the unpacked Ubuntu kit, no Nix), the programs and the contracts come from the kit.
  if [ -n "${KIT_DIR:-}" ]; then printf 'export PATH=%q:"$PATH"\nexport blueprint=%q\n' "$KIT_DIR/bin" "$KIT_DIR/share/plutus.json"; fi
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
  cat "$here/checks.sh"
} >"$work/run.sh"
echo "running $(wc -l <"$work/blocks.sh") lines of pasted blocks; log in $work/log.txt"
bash "$work/run.sh" >"$work/log.txt" 2>&1
rc=$?
tail -22 "$work/log.txt"
echo "log: $work/log.txt"
exit $rc
