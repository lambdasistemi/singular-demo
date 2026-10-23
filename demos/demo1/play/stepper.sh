# shellcheck shell=bash
# Shell setup for the stepper's windows (demos/demo1/play/stepper.sh).
# The tutorial's first page sources this visibly in each window:
#   alice and bob windows:  . ../stepper.sh
#   chain window:           . ./stepper.sh
# It sets what every window's shell needs: the run folder, the programs on
# PATH, the passphrase, the helpers, the window's settings file, and the
# person words.
PLAY_RUN=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PLAY_RUN
# The programs every window needs, resolved to directories when the run was
# set up (the set-up script writes path.env beside this file). Prepended so
# the tutorial's programs win and the system's remain as fallback.
# shellcheck source=/dev/null
. "$PLAY_RUN/path.env"
export PATH="$PLAY_PATH:$PATH"
# The vaults open with this throwaway passphrase; no command asks for it
# (accepted on a private chain only).
export SINGULAR_PASSPHRASE=demo
# The compiled contracts the commands need: in the kit the tutorial directory sits at
# <kit>/share/tutorials/<name>, so the set-up script writes their path into path.env
# beside PLAY_PATH; otherwise the development shell (flake.nix shellHook) provides $blueprint.
# shellcheck disable=SC2154 # PLAY_BLUEPRINT is written by the set-up script in the kit, unset in the repository
export blueprint="${blueprint:-${PLAY_BLUEPRINT:-}}"
# The helpers every window has: koios_url, wait_for_slot, wallet_show.
# They read the chain's settings line through PLAY_RUN.
# shellcheck source=/dev/null
. "$PLAY_RUN/helpers.sh"
# The settings file of the window that sourced this file. The chain needs
# none: it only starts the devnet and reads its settings line.
case "${TUTORIAL_STEPPER_WINDOW:-}" in
  alice) export SINGULAR_CONFIG="$PLAY_RUN/alice/alice.json" ;;
  bob) export SINGULAR_CONFIG="$PLAY_RUN/bob/bob.json" ;;
esac
# The person words. A block that is exactly `alice` or `bob` pins the
# settings file explicitly, so the person switches in the later steps keep
# working in every window.
alice() { export SINGULAR_CONFIG="$PLAY_RUN/alice/alice.json"; }
bob() { export SINGULAR_CONFIG="$PLAY_RUN/bob/bob.json"; }
chain() { :; }
