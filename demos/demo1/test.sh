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
# Runnable blocks are commands and observations; mode=show blocks are shown only and leave no marker.
# After each block the run fails when the block's real exit differs from the one its fence declares
# (0 when the fence names none), naming the file, the block and both statuses.
for f in "$here"/s*.md; do awk -v f="$(basename "$f")" '/^```bash( \{[^}]*\})?$/{if ($0 ~ /mode=show/) {on=0; next} on=1; n++; want=$0; if (sub(/.*status=/, "", want)) sub(/[^0-9].*/, "", want); else want=0; print "echo \"@@ BLOCK " f " " n "\""; next} /^```$/{if (on) print "block_rc=\044?; test \044block_rc -eq " want " || { echo \"FAIL  " f " block " n ": exit \044block_rc, want " want "\"; exit 1; }"; on=0; next} on' "$f"; done >"$work/blocks.sh"
# PROCESS_TIME_MS and RETRACT_TIME_MS, when set, replace the windows the create step writes (a shorter run)
bash "$here/play/short-windows.sh" "$work/blocks.sh" || exit 1
# shellcheck disable=SC2016 # this writes the text of a script: its $ expansions happen when that script runs
{
  printf 'export HOME=%q TMPDIR=%q LOGFILE=%q\nmkdir -p "$HOME" "$TMPDIR"\n' "$work/home" "$work/tmp" "$work/log.txt"
  # With KIT_DIR set (the unpacked Ubuntu kit, no Nix), the programs and the contracts come from the kit.
  if [ -n "${KIT_DIR:-}" ]; then printf 'export PATH=%q:"$PATH"\nexport blueprint=%q\n' "$KIT_DIR/bin" "$KIT_DIR/share/plutus.json"; fi
  # The helpers every window of the play has (koios_url, wait_for_slot, wallet_show), as the play loads them.
  printf 'PLAY_RUN="$HOME/singular-demo-run"\n. %q\n' "$here/play/helpers.sh"
  cat "$work/blocks.sh"
  cat "$here/checks.sh"
} >"$work/run.sh"
echo "running $(wc -l <"$work/blocks.sh") lines of pasted blocks; log in $work/log.txt"
bash "$work/run.sh" >"$work/log.txt" 2>&1
rc=$?
tail -22 "$work/log.txt"
echo "log: $work/log.txt"
exit $rc
