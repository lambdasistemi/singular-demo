#!/usr/bin/env bash
# Lints the repository's own files and checks that it agrees with itself.
#   tools/lint.sh
set -euo pipefail
cd "$(dirname "$0")/.."

find_files() {
  find . -type f "$@" \
    -not -path './.git/*' -not -path './.specify/*' -not -path './killercoda/*' -not -path './site/*' -not -path './result*' \
    -not -path '*/node_modules/*' -not -path '*/.venv/*' -not -path '*/static/vendor/*' | sort
}

fail=0
step() { printf '%s\n' "== $*"; }

step "shell (shellcheck)"
mapfile -t sh_files < <(find_files -name '*.sh')
shellcheck "${sh_files[@]}" || fail=1

step "javascript (biome)"
biome lint . || fail=1

step "python (ruff)"
ruff check tutorial || fail=1

step "workflows (actionlint)"
actionlint -config-file .github/actionlint.yaml .github/workflows/*.yml || fail=1

step "the step files (lint.sh of the demo)"
bash demos/demo1/lint.sh demos/demo1/s*.md demos/pay-by-name/s*.md || fail=1

step "the README and the kit's readme name the Singular version pinned in flake.nix and the kit release"
version=$(node -p "require('./demos/demo1/version.js')")
release=$(node -p "require('./demos/demo1/release.js')")
grep -q "^release=$release\$" README.md || {
  echo "README.md: the release= line is not $release" >&2
  fail=1
}
grep -q "Singular release used is $version\." README.md || {
  echo "README.md: it does not say 'Singular release used is $version.'" >&2
  fail=1
}
grep -q "singular-demo-$release-x86_64-linux" kit/README.txt || {
  echo "kit/README.txt: it does not name singular-demo-$release-x86_64-linux" >&2
  fail=1
}

step "documentation presentation (this site has no narration reader)"
python3 tools/check_presentation.py --no-speech --front README.md README.md docs/index.md docs/demo1/index.md || fail=1

step "the Killercoda scenarios are the generated ones"
generated=$(mktemp -d)
trap 'rm -rf "$generated"' EXIT
bash tools/generate.sh "$generated" >/dev/null
diff -r "$generated/killercoda" killercoda || fail=1
diff "$generated/structure.json" structure.json || fail=1

exit "$fail"
