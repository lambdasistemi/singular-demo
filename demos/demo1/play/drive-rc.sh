# shellcheck shell=bash
# What drive.sh adds to every window of the play (it names this file in PLAY_RC_HOOK): each prompt the shell shows adds
# a line to a file of its pane, so the page knows when a command it typed is over.
mkdir -p "$PLAY_RUN/.drive"
__drive_prompt() { echo >>"$PLAY_RUN/.drive/prompts-${TMUX_PANE#%}"; }
PROMPT_COMMAND="__drive_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
