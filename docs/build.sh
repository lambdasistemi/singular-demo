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
node demos/demo1/build.js
cp demos/demo1/DEMO.md docs/demo1/tutorial.md
cp demos/demo1/demo.html docs/demo1/interactive.html
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
