#!/usr/bin/env bash
# Set-up script for the stepper run (tutorial.toml: setup = "setup.sh").
# Runs in the run folder after the window folders exist and before any page
# command (tutorial-stepper runs it there with --run-setup, as the user who
# started play; it needs no root and installs nothing).
# It makes the per-person folders and the shared publish/messages folders,
# and copies the shell setup the tutorial's first page loads visibly.
set -euo pipefail
run=$(pwd)
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$run"/carol "$run"/alice "$run"/dave "$run"/bob "$run"/publish "$run"/messages
cp "$here/../demo1/play/helpers.sh" "$here/play/stepper.sh" "$run/"
# The programs the windows need, resolved to directories now (the first page
# loads them visibly through stepper.sh, so no window depends on inherited PATH).
path_add=""
for prog in singular open-datum devnet jq curl sink-tools; do
  dir=$(dirname "$(command -v "$prog")")
  case ":$path_add:" in *":$dir:"*) ;; *) path_add="$path_add${path_add:+:}$dir" ;; esac
done
printf 'PLAY_PATH=%q\n' "$path_add" >"$run/path.env"
# In the kit the tutorial directory sits at <kit>/share/tutorials/<name> and the compiled
# contracts travel with it; their path is written down too. In the repository the
# development shell (or CI) provides $blueprint instead, and nothing is written here.
kit_root=$(cd "$here/../../.." && pwd)
if [ -f "$kit_root/share/plutus.json" ]; then
  printf 'PLAY_BLUEPRINT=%q\n' "$kit_root/share/plutus.json" >>"$run/path.env"
fi
echo "The folders of the stepper run are ready: $run"
