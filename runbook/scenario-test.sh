#!/usr/bin/env bash
# Runs a generated Killercoda scenario the way Killercoda runs it, on a clean Ubuntu with no Nix:
#   node runbook/killercoda.js /tmp/scenario
#   docker run --rm --memory 8g -v /tmp/scenario:/scenario:ro -v "$PWD":/repo:ro ubuntu:24.04 \
#     bash /repo/runbook/scenario-test.sh /scenario
# 1. the machine gets curl (Killercoda's has it) and the scenario's intro/background.sh runs: it downloads the kit
# 2. the click-to-run blocks of every step, in the order of index.json, then of the finish page, run in one shell
#    (the test answers the passphrase prompts from files)
# 3. the receipts are checked, as test.sh does
set -u
scenario=$(cd "${1:?usage: scenario-test.sh SCENARIO_DIR}" && pwd)
here=$(cd "$(dirname "$0")" && pwd)
bash "$here/lint.sh" "$scenario"/*/text.md || exit 1
export HOME=/root
cd "$HOME"
if ! command -v curl >/dev/null; then apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null; fi
work=$(mktemp -d /tmp/sc-XXXXXX)
if ! bash "$scenario/intro/background.sh" > "$work/background.log" 2>&1 || [ ! -f /tmp/finished ]; then
  echo "FAIL  intro/background.sh did not finish"; tail -8 "$work/background.log"; exit 1
fi
echo "ok    intro/background.sh finished: $(ls -d "$HOME"/singular-demo-* | head -1)"
pages=$(grep -o '"text": *"[^"]*"' "$scenario/index.json" | cut -d'"' -f4)
for p in $pages; do
  awk '/^```bash$/ {inb=1; buf=""; next}
       inb && /^```\{\{exec\}\}$/ {printf "%s", buf; inb=0; next}
       inb && /^```$/ {inb=0; next}
       inb {buf = buf $0 "\n"}' "$scenario/$p"
done > "$work/blocks.sh"
echo "ok    $(grep -c . "$work/blocks.sh") lines of click-to-run blocks from $(echo "$pages" | wc -l) pages"
{
  printf 'export PASSDIR=%q LOGFILE=%q\nmkdir -p "$PASSDIR"; printf "%%s\\n" "alice test" > "$PASSDIR/alice"; printf "%%s\\n" "bob test" > "$PASSDIR/bob"\n' "$work/pass" "$work/log.txt"
  cat <<'WRAP'
_with_pass() { local prog=$1 a v=""; shift; for a in "$@"; do case "$a" in *.vault) v=$(basename "$a" .vault);; esac; done
  if [ -n "$v" ]; then command "$prog" "$@" --passphrase-fd 3 3< "$PASSDIR/$v"; else command "$prog" "$@"; fi; }
singular() { _with_pass singular "$@"; }
open-datum() { _with_pass open-datum "$@"; }
WRAP
  cat "$work/blocks.sh"
  cat "$here/checks.sh"
} > "$work/run.sh"
bash "$work/run.sh" > "$work/log.txt" 2>&1
rc=$?
tail -24 "$work/log.txt"
exit $rc
