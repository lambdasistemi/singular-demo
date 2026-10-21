#!/usr/bin/env bash
# The tutorial in this terminal, step by step: the page on the left and, beside it, the window of the person who acts,
# in tmux windows like the Killercoda scenario's (alice, bob, chain). Enter types the next command into that window
# and waits until it is over; the words alice, bob and chain on the page move the page beside that window. Everything
# it runs comes from this kit, tmux included.
#   ./drive.sh
#   WORK=/some/folder ./drive.sh   where the run's files are kept (default: ~/singular-demo-run); the folder of an
#                                  earlier run is moved aside, never deleted
#   PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000 ./drive.sh
#                                  the registry's two windows, written into the create step, so the waits on
#                                  the chain last less (the least allowed values; default 180000 and 60000)
#   DRIVE_AUTO=yes ./drive.sh      runs every command and turns every page with no key pressed, and does not attach
#                                  (the kit's own test)
# Run again, it goes back to the same windows and to the page where it was. The windows have a tmux server of their own:
#   bin/tmux -L singular-demo kill-server    ends them
set -euo pipefail
kit=$(cd "$(dirname "$0")" && pwd)
play=$kit/share/play
tmux=("$kit/bin/tmux" -L singular-demo -f /dev/null)

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
              show_block "already done: the page is in tmux, beside Alice's window" "$f"
              continue
              ;;
            alice | bob | chain)
              show_block "Enter moves the page beside the window $first" "$f"
              choose "Enter goes there · n next page · p previous page · q quits" "enter n p q"
              ;;
            *)
              show_block "runs in the window $(window_of)" "$f"
              choose "Enter runs it · s skips it · n next page · p previous page · q quits" "enter s n p q"
              ;;
          esac
          case $k in
            "") case $first in alice | bob | chain) go_to "$first" ;; *) run_block "$f" ;; esac ;;
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
  printf '%s\n' "${dim}That was the whole scenario. The windows stay until tmux ends: bin/tmux -L singular-demo kill-server.$off"
  choose "q closes the page" "q"
}

if [ "${1:-}" = --page ]; then
  page "$2"
  exit
fi

# ---- the start: the folders and the windows of the play, then the page beside Alice's window

if "${tmux[@]}" has-session -t demo 2>/dev/null; then
  run=$("${tmux[@]}" show-options -v -t demo @run)
  echo "The windows of the play are running; the page goes on where it was."
else
  run=${WORK:-$HOME/singular-demo-run}
  if [ -e "$run" ]; then
    saved=$(mktemp -d "$run-saved-$(date +%Y%m%d-%H%M%S)-XXXXXX")
    mv "$run" "$saved/"
    echo "The folder of an earlier run is kept in $saved"
  fi
  bash "$play/prepare.sh" "$kit" "$run"
  run=$(cd "$run" && pwd)
  # the pages this run plays, with the windows of the environment written in
  mkdir -p "$run/.drive"
  cp -r "$kit/share/scenario" "$run/.drive/scenario"
  bash "$play/short-windows.sh" "$run/.drive/scenario"
  # a server of this socket with no play in it is left over: the windows need one that starts with PLAY_RC_HOOK
  "${tmux[@]}" kill-server 2>/dev/null || true
  env -u TMUX PLAY_RC_HOOK="$play/drive-rc.sh" PLAY_TMUX="${tmux[*]}" bash "$play/windows.sh" "$run"
  "${tmux[@]}" set-option -t demo @run "$run"
fi
pane=$(cat "$run/.drive/page-pane" 2>/dev/null || true)
if [ -z "$pane" ] || ! "${tmux[@]}" list-panes -a -F '#{pane_id}' | grep -qxF "$pane"; then
  window=$(cat "$run/.drive/window" 2>/dev/null || echo alice)
  "${tmux[@]}" split-window -h -b -l 45% -t "demo:$window" \
    "$(printf '%q ' env DRIVE_AUTO="${DRIVE_AUTO:-no}" bash "$kit/drive.sh" --page "$run")"
  "${tmux[@]}" select-window -t "demo:$window"
fi
if [ "${DRIVE_AUTO:-no}" = yes ] || [ ! -t 1 ]; then
  echo "The page and the windows are in tmux: $kit/bin/tmux -L singular-demo attach -t demo"
  exit 0
fi
exec env -u TMUX "${tmux[@]}" attach -t demo
