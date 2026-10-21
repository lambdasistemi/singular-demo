#!/usr/bin/env bash
# The tutorial in this terminal, step by step: the page on the left and, beside it, the window of the person who acts,
# in tmux windows like the Killercoda scenario's. Enter types the next command into that window and waits until it is
# over; the name of a window on the page moves the page beside that window. Everything it runs comes from this kit,
# tmux and node included.
#   ./drive.sh                     Demo 1, in the windows alice, bob and chain
#   ./drive.sh pay-by-name         the pay-by-name story, in the windows carol, alice, dave, bob and chain
#   WORK=/some/folder ./drive.sh   where the run's files are kept (default: ~/singular-demo-run for Demo 1 and
#                                  ~/singular-pay-by-name-run for pay-by-name); the folder of an earlier run is moved
#                                  aside, never deleted
#   PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000 ./drive.sh
#                                  Demo 1 only: the registry's two windows, written into the create step, so the waits
#                                  on the chain last less (the least allowed values; default 180000 and 60000)
#   DRIVE_AUTO=yes ./drive.sh      runs every command and turns every page with no key pressed, and does not attach
#                                  (the kit's own test)
# Run again, it goes back to the same windows and to the page where it was. Each scenario has a tmux server of its own:
#   bin/tmux -L singular-demo kill-server           ends the windows of Demo 1
#   bin/tmux -L singular-pay-by-name kill-server    ends the windows of pay-by-name
set -euo pipefail
kit=$(cd "$(dirname "$0")" && pwd)

# ---- the scenario: its windows, its pages and play scripts, its tmux server
# The page runs again in a pane of its own (drive.sh --page), and finds its scenario in DRIVE_SCENARIO.
if [ "${1:-}" = --page ]; then name=${DRIVE_SCENARIO:-demo1}; else name=${1:-demo1}; fi
case $name in
  demo1)
    windows="alice bob chain"
    play=$kit/share/play
    pages=$kit/share/scenario
    socket=singular-demo
    default_work=$HOME/singular-demo-run
    ;;
  pay-by-name)
    windows="carol alice dave bob chain"
    play=$kit/share/pay-by-name/play
    pages=$kit/share/pay-by-name/scenario
    socket=singular-pay-by-name
    default_work=$HOME/singular-pay-by-name-run
    ;;
  *)
    echo "usage: ./drive.sh [pay-by-name]    (no argument: Demo 1)" >&2
    exit 2
    ;;
esac
start_window=${windows%% *} # the window the page starts beside: the first of the scenario's windows
tmux=("$kit/bin/tmux" -L "$socket" -f /dev/null)

# ---- the page: it runs in a pane beside the window of the person who acts

e=$'\e'
bold="${e}[1m" unbold="${e}[22m" accent="${e}[36m" plain="${e}[39m" dim="${e}[2m" off="${e}[0m" frame="${e}[33m"

page_parts() { # FILE DIR: the page cut into its parts, in order: NNN.text, NNN.run (a block to run), NNN.show (shown only)
  rm -rf "$2" && mkdir -p "$2"
  awk -v d="$2" '
    function part(kind) { close(f); n++; f = sprintf("%s/%03d.%s", d, n, kind) }
    BEGIN { part("text") }
    !inb && /^```/ { inb = 1; body = ""; next }
    inb && /^```(\{\{exec\}\})?$/ { part($0 ~ /exec/ ? "run" : "show"); printf "%s", body > f; part("text"); inb = 0; next }
    inb { body = body $0 "\n"; next }
    { print > f }' "$1"
}

render() { # markdown text for the terminal: bold, code and links marked, wrapped to the width of the pane
  local cols
  cols=$(stty size 2>/dev/null | cut -d' ' -f2)
  sed -E -e "s/\*\*([^*]+)\*\*/$bold\1$unbold/g" \
    -e "s/\`([^\`]+)\`/$accent\1$plain/g" \
    -e "s/\[([^]]+)\]\(([^)]+)\)/\1 $dim\2$off/g" \
    -e 's/^- /• /' |
    awk -v w=$((${cols:-80} - 2)) -v esc="$e" '
      function vis(s) { gsub(esc "\\[[0-9;]*m", "", s); return length(s) }
      $0 == "" { print; next }
      { lead = $0 ~ /^• / ? "  " : ""; n = split($0, word, " "); line = ""
        for (i = 1; i <= n; i++)
          if (line == "") line = word[i]
          else if (vis(line) + 1 + vis(word[i]) > w) { print line; line = lead word[i] }
          else line = line " " word[i]
        print line }'
}

show_block() { # LABEL FILE: a block of the page, framed, with what happens to it
  printf '%s┌ %s%s\n' "$frame" "$1" "$off"
  sed "s/^/$frame│$off /" "$2"
  printf '%s└%s\n' "$frame" "$off"
}

status() { # TEXT: one line at the bottom, cut to the width of the pane, so the next one replaces it
  local cols
  cols=$(stty size 2>/dev/null | cut -d' ' -f2)
  printf '\r%s%s%s%s' "${e}[K" "$dim" "${1:0:${cols:-80}-1}" "$off"
}

choose() { # PROMPT KEYS: shows the keys on one line and reads one of them into k; Enter is the empty key
  if [ "$auto" = yes ]; then
    k=
    return
  fi
  while :; do
    status "$1"
    IFS= read -rsn1 k || k=q
    printf '\r%s' "${e}[K"
    case " $2 " in *" ${k:-enter} "*) return ;; esac
  done
}

is_window() { case " $windows " in *" $1 "*) return 0 ;; *) return 1 ;; esac }
window_of() { "${tmux[@]}" display-message -p -t "$me" '#{window_name}'; }
shell_pane() { "${tmux[@]}" list-panes -t "$me" -F '#{pane_id}' | grep -vxF "$me" | head -1; }
prompts() { if [ -f "$1" ]; then wc -l <"$1"; else echo 0; fi; }

go_to() { # WINDOW: the page moves beside that window, which comes to the front
  [ "$(window_of)" = "$1" ] || "${tmux[@]}" join-pane -h -b -l 45% -s "$me" -t "demo:$1"
  "${tmux[@]}" select-window -t "demo:$1"
  "${tmux[@]}" select-pane -t "$me"
  echo "$1" >"$state/window"
}

run_block() { # FILE: types the block into the shell beside the page, one command at a time, each after the prompt of the one before
  local pane window file base start line
  local -a lines
  pane=$(shell_pane)
  window=$(window_of)
  file=$state/prompts-${pane#%}
  [ -f "$file" ] || printf '%s\n' "${dim}This window does not report its prompt: the page types the block without waiting.$off"
  mapfile -t lines <"$1"
  base=$(prompts "$file")
  for line in "${lines[@]}"; do
    [ -n "$line" ] || continue
    "${tmux[@]}" send-keys -t "$pane" -l -- "$line"
    "${tmux[@]}" send-keys -t "$pane" Enter
    case $line in *\\) continue ;; esac # the command goes on, on the next line
    [ -f "$file" ] || continue
    start=$SECONDS
    until [ "$(prompts "$file")" -gt "$base" ]; do
      status "running in the window $window, $((SECONDS - start))s · c sends Ctrl-C · s stops waiting"
      if [ "$auto" = yes ]; then
        sleep 0.3
        continue
      fi
      k=
      IFS= read -rsn1 -t 0.3 k || continue
      case $k in
        c) "${tmux[@]}" send-keys -t "$pane" C-c ;;
        s)
          printf '\r%s%s\n' "${e}[K" "${dim}The page stopped waiting; the rest of the block was not typed.$off"
          return
          ;;
      esac
    done
    printf '\r%s' "${e}[K"
    base=$(prompts "$file")
  done
  printf '%s\n' "${dim}done in the window $window$off"
}

page() { # RUN: the pages of the scenario, from the one where the page was last
  set +e
  local run=$1 p next turned f first
  local -a texts titles
  state=$run/.drive
  scenario=$state/scenario
  me=$TMUX_PANE
  auto=${DRIVE_AUTO:-no}
  mkdir -p "$state"
  echo "$me" >"$state/page-pane"
  # Killercoda's intro is about its own machine; here the scenario starts at its first step
  mapfile -t texts < <("$kit/bin/jq" -r '.details.steps[].text, .details.finish.text' "$scenario/index.json")
  mapfile -t titles < <("$kit/bin/jq" -r '.details.steps[].title, "The end"' "$scenario/index.json")
  p=$(cat "$state/page" 2>/dev/null || echo 0)
  while [ "$p" -lt "${#texts[@]}" ]; do
    echo "$p" >"$state/page"
    printf '%s' "${e}[H${e}[2J"
    printf '%s%s%s  %s%d of %d · where the page says click, press Enter%s\n\n' \
      "$bold" "${titles[p]}" "$unbold" "$dim" $((p + 1)) "${#texts[@]}" "$off"
    page_parts "$scenario/${texts[p]}" "$state/parts"
    next=$((p + 1))
    turned=no
    for f in "$state/parts"/*; do
      case $f in
        *.text) render <"$f" ;;
        *.show) show_block "shown only, not run" "$f" ;;
        *.run)
          first=$(head -1 "$f")
          case $first in
            "tmux attach -t demo"*)
              show_block "already done: the page is in tmux, beside the window $start_window" "$f"
              continue
              ;;
            *)
              if is_window "$first"; then
                show_block "Enter moves the page beside the window $first" "$f"
                choose "Enter goes there · n next page · p previous page · q quits" "enter n p q"
              else
                show_block "runs in the window $(window_of)" "$f"
                choose "Enter runs it · s skips it · n next page · p previous page · q quits" "enter s n p q"
              fi
              ;;
          esac
          case $k in
            "") if is_window "$first"; then go_to "$first"; else run_block "$f"; fi ;;
            n) turned=yes && break ;;
            p) next=$((p > 0 ? p - 1 : 0)) turned=yes && break ;;
            q) exit 0 ;;
          esac
          echo
          ;;
      esac
    done
    if [ "$turned" = no ]; then
      choose "end of the page · Enter or n next page · p previous page · q quits" "enter n p q"
      case $k in
        p) next=$((p > 0 ? p - 1 : 0)) ;;
        q) exit 0 ;;
      esac
    fi
    p=$next
  done
  echo "$p" >"$state/page"
  [ "$auto" = yes ] && exit 0
  printf '%s\n' "${dim}That was the whole scenario. The windows stay until tmux ends: bin/tmux -L $socket kill-server.$off"
  choose "q closes the page" "q"
}

if [ "${1:-}" = --page ]; then
  page "$2"
  exit
fi

# ---- the start: the folders and the windows of the play, then the page beside the first window

if "${tmux[@]}" has-session -t demo 2>/dev/null; then
  run=$("${tmux[@]}" show-options -v -t demo @run)
  echo "The windows of the play are running; the page goes on where it was."
else
  run=${WORK:-$default_work}
  if [ -e "$run" ]; then
    saved=$(mktemp -d "$run-saved-$(date +%Y%m%d-%H%M%S)-XXXXXX")
    mv "$run" "$saved/"
    echo "The folder of an earlier run is kept in $saved"
  fi
  bash "$play/prepare.sh" "$kit" "$run"
  run=$(cd "$run" && pwd)
  # the pages this run plays, with the windows of the environment written in
  mkdir -p "$run/.drive"
  cp -r "$pages" "$run/.drive/scenario"
  # the windows of the registry, for the scenario whose create step has them
  [ ! -f "$play/short-windows.sh" ] || bash "$play/short-windows.sh" "$run/.drive/scenario"
  # a server of this socket with no play in it is left over: the windows need one that starts with PLAY_RC_HOOK
  "${tmux[@]}" kill-server 2>/dev/null || true
  env -u TMUX PLAY_RC_HOOK="$play/drive-rc.sh" PLAY_TMUX="${tmux[*]}" bash "$play/windows.sh" "$run"
  "${tmux[@]}" set-option -t demo @run "$run"
fi
pane=$(cat "$run/.drive/page-pane" 2>/dev/null || true)
if [ -z "$pane" ] || ! "${tmux[@]}" list-panes -a -F '#{pane_id}' | grep -qxF "$pane"; then
  window=$(cat "$run/.drive/window" 2>/dev/null || echo "$start_window")
  "${tmux[@]}" split-window -h -b -l 45% -t "demo:$window" \
    "$(printf '%q ' env DRIVE_AUTO="${DRIVE_AUTO:-no}" DRIVE_SCENARIO="$name" bash "$kit/drive.sh" --page "$run")"
  "${tmux[@]}" select-window -t "demo:$window"
fi
if [ "${DRIVE_AUTO:-no}" = yes ] || [ ! -t 1 ]; then
  echo "The page and the windows are in tmux: $kit/bin/tmux -L $socket attach -t demo"
  exit 0
fi
exec env -u TMUX "${tmux[@]}" attach -t demo
