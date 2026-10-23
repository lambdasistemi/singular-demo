#!/usr/bin/env bash
# A command that asks for a passphrase must be the last command of its block. A terminal that types a whole block
# at once (Killercoda does) hands the lines after the command to the prompt as the passphrase.
#   bash runbook/lint.sh FILE.md...
# Every command block also names its window on the fence. The tutorial-stepper form is
#   ```bash { window=alice status=19 mode=observe }
# window is required; status only when the block ends non-zero; mode only show or observe.
# The pay-by-name story still uses the word form ```bash PERSON / ```bash skip, accepted here.
fail=0
for f in "$@"; do
  out=$(awk -v f="$f" '
    /^```bash \{.*\}$/ {
      attrs=$0; sub(/^```bash \{/, "", attrs); sub(/\}$/, "", attrs); gsub(/^ +| +$/, "", attrs)
      if (attrs !~ /(^| )window=[A-Za-z0-9]+($| )/) { printf "%s:%d: fence without window=...\n", f, NR; next }
      n=split(attrs, kv, / +/)
      for (i=1; i<=n; i++) {
        if (kv[i] ~ /^window=[A-Za-z0-9]+$/) continue
        if (kv[i] ~ /^status=[0-9]+$/) continue
        if (kv[i] ~ /^mode=(show|observe)$/) continue
        printf "%s:%d: bad attribute %s\n", f, NR, kv[i]
      }
      next }
    /^```bash [A-Za-z]+$/ { next }
    /^```bash$/ { printf "%s:%d: bare fence without attributes (want ```bash { window=... })\n", f, NR; next }
    /^```bash / { printf "%s:%d: malformed fence attributes\n", f, NR; next }
  ' "$f")
  [ -z "$out" ] || {
    echo "$out"
    fail=1
  }
done
[ $fail = 0 ] && echo "ok    every block names its window on the fence"
# Fails, naming file and line, for every block where a command naming a vault is followed by another command.
for f in "$@"; do
  out=$(awk -v f="$f" '
    /^```bash/ { inb=1; n=0; start=NR; next }
    inb && /^```/ {
      cur=""; cmds=0
      for (i=1; i<=n; i++) { cur = (cur=="" ? L[i] : cur " " L[i]); if (L[i] !~ /\\$/) { C[++cmds]=cur; cur="" } }
      for (c=1; c<cmds; c++) if (C[c] ~ /--vault/) { printf "%s:%d: a command that asks for a passphrase is followed by %d more in the same block\n", f, start, cmds-c; break }
      inb=0; next }
    inb { L[++n]=$0 }' "$f")
  [ -z "$out" ] || {
    echo "$out"
    fail=1
  }
done
[ $fail = 0 ] && echo "ok    no block has a passphrase prompt followed by another command"
exit $fail
