#!/usr/bin/env bash
# Formats the repository's own files, or checks that they are formatted.
#   tools/format.sh check   exit 1 and name the files that differ
#   tools/format.sh write   rewrite them
# The Killercoda scenarios (killercoda/) and the site are generated and are never formatted by hand.
set -euo pipefail
cd "$(dirname "$0")/.."
mode=${1:?usage: tools/format.sh check|write}
case "$mode" in check | write) ;; *)
  echo "usage: tools/format.sh check|write" >&2
  exit 2
  ;;
esac

find_files() {
  find . -type f "$@" \
    -not -path './.git/*' -not -path './.specify/*' -not -path './killercoda/*' -not -path './site/*' -not -path './result*' \
    -not -path '*/node_modules/*' -not -path '*/.venv/*' -not -path '*/static/vendor/*' | sort
}

fail=0
step() { printf '%s\n' "== $*"; }

step "nix (nixfmt)"
mapfile -t nix_files < <(find_files -name '*.nix')
if [ "$mode" = check ]; then nixfmt --check "${nix_files[@]}" || fail=1; else nixfmt "${nix_files[@]}"; fi

step "shell (shfmt)"
mapfile -t sh_files < <(find_files \( -name '*.sh' -o -name '*.rc' \))
if [ "$mode" = check ]; then shfmt -ln bash -i 2 -ci -d "${sh_files[@]}" || fail=1; else shfmt -ln bash -i 2 -ci -w "${sh_files[@]}"; fi

step "javascript and json (biome)"
if [ "$mode" = check ]; then biome format . || fail=1; else biome format --write .; fi

step "python (ruff)"
if [ "$mode" = check ]; then ruff format --check tutorial || fail=1; else ruff format tutorial; fi

exit "$fail"
