#!/usr/bin/env bash
# Builds the documentation site into site/.
#   docs/build.sh TRANSCRIPT DEMO_RUN_LOG
#     TRANSCRIPT     the transcript of tutorial-stepper play --auto demos/demo1 (a real run of the tutorial)
#     DEMO_RUN_LOG   demo-run.log of the kit's annotated script
# The pages that show runs are made from these two logs and are not kept in git.
set -euo pipefail
cd "$(dirname "$0")/.."
runbook_log=${1:?usage: docs/build.sh TRANSCRIPT DEMO_RUN_LOG}
demo_log=${2:?usage: docs/build.sh TRANSCRIPT DEMO_RUN_LOG}
grep -q '^All 16 steps passed\.' "$demo_log"
grep -q '^no: test -e /nix fails' "$demo_log"
# build.js writes beside the step files by default; keep the tutorial directory
# free of generated pages (check rejects an unlisted page) with an output dir.
rendered=$(mktemp -d)
trap 'rm -rf "$rendered"' EXIT
node demos/demo1/build.js "$rendered"
{
  printf '# Singular Demo 1, step by step\n\nFollow Alice as she registers a key, changes its payload and permanently terminates it. Carol starts the registry; Bob folds the registration and termination.\n\n## Registry lifecycle\n\n'
  awk '/^```mermaid$/ { on=1 } on { print } on && /^```$/ { exit }' README.md
  printf '\nA terminated key cannot be registered again. Carol creates the registry before Alice begins.\n\n'
  tail -n +2 "$rendered/DEMO.md"
} >docs/demo1/tutorial.md
cp "$rendered/demo.html" docs/demo1/interactive.html
python3 demos/demo1/render-run.py "$runbook_log" docs/demo1/run.md
# shellcheck disable=SC2016 # the backticks in the text are Markdown, not command substitution
{
  printf '# The annotated script, as it ran\n\n'
  printf 'The kit'"'"'s own script, `demo.sh`, played all 16 steps of Demo 1 in a clean Ubuntu 24.04 container with no Nix and no network. Its log, unedited:\n\n'
  printf '```text\n'
  sed 's/\r$//' "$demo_log"
  printf '```\n'
} >docs/demo1/script-run.md
mkdocs build --strict -d site
