#!/usr/bin/env bash
# What the story leaves in the folders of its five people, and on their screens, and what each must say. The scenario test
# (Killercoda's windows) and the kit's terminal test (stepper-run.sh) both judge their run with it.
#   check-run.sh RUN_DIR [SCREENS_DIR]
#     RUN_DIR      the folder of the play (carol, alice, dave, bob, publish, messages)
#     SCREENS_DIR  when given, the screens of the windows as files window-NAME.log; what they show is checked too
#   needs jq; exit 0 only if everything holds
# shellcheck disable=SC2016 # jq programs: the $ names are jq's, not the shell's
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
check() { # FILE [jq options...] FILTER
  local file=$1 filter=${!#}
  set -- "${@:2:$#-2}"
  if jq -e "$@" "$filter" "$file" >/dev/null 2>&1; then ok "$file  $filter"; else bad "$file  $filter"; fi
}
check carol/create.json '.outcome=="success"'
check publish/registry.json '(."sink-script"|length)>1000 and (.registry|test("^singular_devnet1[0-9a-z]+$")) and (has("state-token")|not)'
check alice/insert.json '.outcome=="success"'
check alice/fold.json '.outcome=="success"'
check alice/inspect.json '.leaf=="active" and .keyText=="alice"'
# the address is a payload with no plain reading: inspect prints it in the detailed form, as the file Alice booked it from
check alice/inspect.json --slurpfile p alice/payload.json '.applicationOutput.payloadSchema=="detailed" and .applicationOutput.payload==$p[0]'
# each person's settings name the registry by its address, the one Carol published, and by nothing else
for who in carol alice dave bob; do
  check "$who/singular.json" --slurpfile p publish/registry.json '.registry==$p[0].registry and (has("state-token")|not)'
done
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
  for line in '^application: matches' '^published registry: matches' '^published registry sink script: matches'; do
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
