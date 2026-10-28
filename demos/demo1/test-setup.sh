#!/usr/bin/env bash
# Exercise tutorial setup in an isolated run folder, including each actor's own files.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
run=$(mktemp -d)
trap 'rm -rf "$run"' EXIT
(cd "$run" && bash "$here/setup.sh")
for who in alice bob carol; do
  for dir in receipts bundles witnesses; do test -d "$run/$who/$dir"; done
  jq -e 'type == "object" and length == 0' "$run/$who/$who.json" >/dev/null
  test ! -e "$run/$who/$who.vault"
done
# A repeat keeps an actor's existing settings intact.
printf '{"state-dir":"my-state"}\n' >"$run/carol/carol.json"
(cd "$run" && bash "$here/setup.sh")
jq -e '.["state-dir"] == "my-state"' "$run/carol/carol.json" >/dev/null
printf 'Actor setup passed.\n'
