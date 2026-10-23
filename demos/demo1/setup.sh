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
mkdir -p "$run"/alice/{receipts,bundles,witnesses} "$run"/bob/{receipts,bundles,witnesses}
# The settings files of Alice and Bob, each in the person's folder; the steps fill them.
for who in alice bob; do [ -f "$run/$who/$who.json" ] || echo '{}' >"$run/$who/$who.json"; done
cp "$here/play/helpers.sh" "$here/play/stepper.sh" "$run/"
echo "The folders of the stepper run are ready: $run"
