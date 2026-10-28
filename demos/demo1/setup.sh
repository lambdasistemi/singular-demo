#!/usr/bin/env bash
# Set-up script for the stepper run (tutorial.toml: setup = "setup.sh").
# Runs in the run folder after the window folders exist and before any page
# command (tutorial-stepper runs it there with --run-setup, as the user who
# started play; it needs no root and installs nothing).
# It makes the per-person receipt, bundle and witness folders, empty settings
# files, and copies the shell setup the tutorial's first page loads visibly.
set -euo pipefail
run=$(pwd)
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$run"/alice/{receipts,bundles,witnesses} "$run"/bob/{receipts,bundles,witnesses} "$run"/carol/{receipts,bundles,witnesses}
# The settings files of Carol, Alice and Bob, each in the person's folder; the steps fill them.
for who in alice bob carol; do [ -f "$run/$who/$who.json" ] || echo '{}' >"$run/$who/$who.json"; done
cp "$here/play/helpers.sh" "$here/play/stepper.sh" "$run/"
chmod u+w "$run/helpers.sh" "$run/stepper.sh"
# The programs the windows need, resolved to directories now (the first page
# loads them visibly through stepper.sh, so no window depends on inherited PATH).
path_add=""
for prog in singular open-datum devnet jq curl; do
  dir=$(dirname "$(command -v "$prog")")
  case ":$path_add:" in *":$dir:"*) ;; *) path_add="$path_add${path_add:+:}$dir" ;; esac
done
printf 'PLAY_PATH=%q\n' "$path_add" >"$run/path.env"
# The compiled contracts travel beside the tutorial: <kit>/share/plutus.json in the kit,
# <prefix>/share/singular-demo/plutus.json in a Homebrew install. In the repository the
# development shell (or CI) provides $blueprint instead, and nothing is written here.
if [ -f "$here/../../plutus.json" ]; then
  printf 'PLAY_BLUEPRINT=%q\n' "$here/../../plutus.json" >>"$run/path.env"
fi
echo "The folders of the stepper run are ready: $run"
