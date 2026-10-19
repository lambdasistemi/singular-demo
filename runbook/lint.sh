#!/usr/bin/env bash
# A command that asks for a passphrase must be the last command of its block. A terminal that types a whole block
# at once (Killercoda does) hands the lines after the command to the prompt as the passphrase.
#   bash runbook/lint.sh FILE.md...
# Fails, naming file and line, for every block where a command naming a vault is followed by another command.
fail=0
for f in "$@"; do
  out=$(awk -v f="$f" '
    /^```bash/ { inb=1; n=0; start=NR; next }
    inb && /^```/ {
      cur=""; cmds=0
      for (i=1; i<=n; i++) { cur = (cur=="" ? L[i] : cur " " L[i]); if (L[i] !~ /\\$/) { C[++cmds]=cur; cur="" } }
      for (c=1; c<cmds; c++) if (C[c] ~ /--vault/) { printf "%s:%d: a command that asks for a passphrase is followed by %d more in the same block\n", f, start, cmds-c; break }
      inb=0; next }
    inb { L[++n]=$0 }' "$f")
  [ -z "$out" ] || { echo "$out"; fail=1; }
done
[ $fail = 0 ] && echo "ok    no block has a passphrase prompt followed by another command"
exit $fail
