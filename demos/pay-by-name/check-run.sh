#!/usr/bin/env bash
# What the story leaves in the folders of its five people, and on their screens, and what each must say. The scenario test
# (Killercoda's windows) and the kit's terminal test (drive.sh) both judge their run with it.
#   check-run.sh RUN_DIR [SCREENS_DIR]
#     RUN_DIR      the folder of the play (carol, alice, dave, bob, publish, messages)
#     SCREENS_DIR  when given, the screens of the windows as files window-NAME.log; what they show is checked too
#   needs jq; exit 0 only if everything holds
set -u
run=${1:?usage: check-run.sh RUN_DIR [SCREENS_DIR]}
screens=${2:-}
cd "$run" || exit 1
fail=0
ok() { echo "ok    $1"; }
bad() {
  echo "FAIL  $1"
  fail=1
}
check() { if jq -e "$2" "$1" >/dev/null 2>&1; then ok "$1  $2"; else bad "$1  $2"; fi; }
check carol/create.json '.outcome=="success"'
check publish/registry.json '(."sink-script"|length)>1000 and (."state-token"|test("^[0-9a-f]{56}[.][0-9a-f]{64}$"))'
check alice/insert.json '.outcome=="success"'
check alice/fold.json '.outcome=="success"'
check alice/inspect.json '.leaf=="active" and .keyText=="alice"'
check dave/fold.json '.outcome=="success"'
check dave/inspect.json '.leaf=="active" and .keyText=="dave"'
check bob/fund.submitted.json '.outcome=="success"'
check alice/move.submitted.json '.outcome=="success"'
check dave/move.submitted.json '.outcome=="success"'
check alice/update.json '.outcome=="success"'
check alice/new.submitted.json '.outcome=="success"'
if [ "$(cat messages/alice-to-bob.txt 2>/dev/null)" = alice ] && [ "$(cat messages/dave-to-bob.txt 2>/dev/null)" = dave ]; then
  ok "the replies name alice and dave"
else bad "the replies are not alice and dave"; fi

if [ -n "$screens" ]; then
  log=$(mktemp)
  cat "$screens"/window-carol.log "$screens"/window-alice.log "$screens"/window-dave.log "$screens"/window-bob.log >"$log"
  count() { grep -c -- "$1" "$log"; }
  for line in '^application: matches' '^published registry sink script: matches' '^active policy: matches describe'; do
    if [ "$(count "$line")" -ge 3 ]; then ok "three checks say: ${line#^}"; else bad "fewer than three checks say: ${line#^}"; fi
  done
  if grep -q "^Alice controls 'alice'" "$log" && grep -q "^Dave controls 'dave'" "$log"; then
    ok "the screens say: Alice controls 'alice', Dave controls 'dave'"
  else bad "a controller line is missing on the screens"; fi
  if grep -q 'sink refuses this move: .*Trace sink-conservation' "$screens/window-alice.log"; then
    ok "the move to the old address was refused: sink-conservation"
  else bad "no refusal with sink-conservation in Alice's window"; fi
  rm -f "$log"
fi
exit $fail
