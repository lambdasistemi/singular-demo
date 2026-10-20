# Sourced by the outer terminal and each of the three tmux windows.
[[ ! -f ~/.bashrc ]] || source ~/.bashrc
bind 'set enable-bracketed-paste on'
PS1='\[\e[32m\]singular\[\e[0m\] \w $ '
# File signals survive tmux redraws and window switches without interpreting screen text.
__tutorial_prompt() { printf 1 > "$TUTORIAL_STATE_DIR/$BASHPID.ready"; }
PROMPT_COMMAND=__tutorial_prompt
trap '[[ $BASH_COMMAND == __tutorial_prompt ]] || printf 0 > "$TUTORIAL_STATE_DIR/$BASHPID.ready"' DEBUG
trap 'jobs -pr | xargs -r kill 2>/dev/null || true' EXIT
tmux() { command tmux -L "$TUTORIAL_TMUX_SOCKET" "$@"; }
