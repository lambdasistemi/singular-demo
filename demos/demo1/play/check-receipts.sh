#!/usr/bin/env bash
# The receipts a whole run of the two-window scenario leaves in Alice's and Bob's folders, and what each must say.
# The scenario test (Killercoda's windows) and the kit's terminal test (drive.sh) both judge their run with it.
#   check-receipts.sh RUN_DIR    needs jq; exit 0 only if every receipt holds
# shellcheck disable=SC2016 # jq programs: the $ names are jq's, not the shell's
set -u
cd "${1:?usage: check-receipts.sh RUN_DIR}" || exit 1
fail=0
check() { # FILE [jq options...] FILTER
  local file=$1 filter=${!#}
  set -- "${@:2:$#-2}"
  if jq -e "$@" "$filter" "$file" >/dev/null 2>&1; then echo "ok    $file  $filter"; else
    echo "FAIL  $file  $filter"
    fail=1
  fi
}
check alice/receipts/01-create.json '.outcome=="success"'
check alice/receipts/02-describe.json '.outcome=="success" and .rules.processTime>0'
check bob/receipts/02-describe-bob.json '.outcome=="success" and .rules.processTime>0'
# the registry is named by its address alone: the one create printed is in Alice's file and, handed over, in Bob's;
# neither file has a state token; both pages name the same registry
registry=$(jq -r .registry alice/receipts/01-create.json)
check alice/receipts/01-create.json '.registry|test("^singular_devnet1[0-9a-z]+$")'
check alice/alice.json --arg r "$registry" '.registry==$r and has("network-magic") and (has("state-token")|not)'
check bob/bob.json --arg r "$registry" '.registry==$r and has("network-magic") and (has("state-token")|not)'
if [ "$(cat registry.address)" = "$registry" ]; then echo "ok    registry.address holds the address and nothing else"; else
  echo "FAIL  registry.address is not the address create printed"
  fail=1
fi
if jq -e -s '.[0].registry.address == .[1].registry.address' alice/receipts/02-describe.json bob/receipts/02-describe-bob.json >/dev/null 2>&1; then
  echo "ok    Alice's page and Bob's page name the same registry"
else
  echo "FAIL  Alice's page and Bob's page do not name the same registry"
  fail=1
fi
check alice/receipts/03-insert-alice.json '.outcome=="success"'
check bob/receipts/04-fold-insert.json '.outcome=="waiting-for-signatures"'
check bob/receipts/04-fold-insert.submitted.json '(.submissions|length)>=1'
check alice/receipts/05-inspect.json '.leaf=="active"'
check alice/receipts/06-update.json '.outcome=="success"'
check alice/receipts/08-terminate.json '.outcome=="success"'
check bob/receipts/09-fold-terminate.json '.outcome=="waiting-for-signatures"'
check alice/receipts/10-inspect.json '.leaf=="terminal"'
check bob/receipts/11b-reject-too-early.json '.outcome=="client-refusal"'
check bob/receipts/11d-reject.json '.outcome=="waiting-for-signatures"'
check bob/receipts/12-insert-bob.json '.outcome=="waiting-for-signatures"'
check alice/receipts/13-fold-bob.json '.outcome=="success"'
check alice/receipts/14b-reclaim-too-early.json '.outcome=="client-refusal"'
check alice/receipts/14c-reclaim.json '.outcome=="success"'
check alice/receipts/15-insert-dave.json '.outcome=="success"'
check alice/receipts/16b-inspect-dave.json '.leaf=="active"'
exit $fail
