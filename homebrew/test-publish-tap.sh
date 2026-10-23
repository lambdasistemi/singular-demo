#!/usr/bin/env bash
# Test that the Homebrew formulas publish from the dev shell.
#   homebrew/test-publish-tap.sh TAG
# Executes homebrew/publish-tap.sh against the published release TAG: the dry run
# renders both formulas and pushes nothing (no tap token needed); a tag whose release
# or tools tarball is missing fails; publishing without a tap token fails.
# Exit 0 only if every check holds.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)

fail=0
check() { # description, test result (0 = holds)
  if [ "$2" -eq 0 ]; then echo "  ok    $1"; else
    echo "  FAIL  $1"
    fail=1
  fi
}

# The published release under test: the CI job passes the latest published release
# from `gh release view`, so the missing-tag and missing-token checks below run on
# every pull request too.
tag=${1:?usage: test-publish-tap.sh TAG}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

out=$(env -u TAP_TOKEN bash "$here/publish-tap.sh" --dry-run --tag "$tag" --out "$work" 2>"$work/stderr.log")
check "dry run without a tap token exits 0" $?
check "dry run names both formulas" "$(echo "$out" | grep -q "singular@0.16.rb" && echo "$out" | grep -q "singular-demo.rb" && echo 0 || echo 1)"
check "dry run renders singular@0.16.rb" "$([ -s "$work/singular@0.16.rb" ] && echo 0 || echo 1)"
check "dry run renders singular-demo.rb" "$([ -s "$work/singular-demo.rb" ] && echo 0 || echo 1)"
check "demo formula fetches the tag tarball" "$(grep -qF "singular-demo/archive/refs/tags/$tag.tar.gz" "$work/singular-demo.rb" 2>/dev/null && echo 0 || echo 1)"
check "demo formula fetches the tag tools" "$(grep -qF "pay-by-name-tools-$tag.tar.gz" "$work/singular-demo.rb" 2>/dev/null && echo 0 || echo 1)"
check "no unrendered placeholder remains" "$(grep -q '@[A-Z_]*@' "$work/singular@0.16.rb" "$work/singular-demo.rb" 2>/dev/null && echo 1 || echo 0)"
check "dry run pushes nothing" "$(grep -qi "push" "$work/stderr.log" 2>/dev/null && echo 1 || echo 0)"

# A tag whose release or tools tarball is missing fails instead of rendering.
if bash "$here/publish-tap.sh" --dry-run --tag v0.0.0-nonexistent-0 --out "$work/missing" >/dev/null 2>&1; then
  check "missing tag fails" 1
else
  check "missing tag fails" 0
fi

# Publishing without a tap token fails fast (the workflow always mints one).
if env -u TAP_TOKEN bash "$here/publish-tap.sh" --tag "$tag" --out "$work/pub" >/dev/null 2>&1; then
  check "publish without TAP_TOKEN fails" 1
else
  check "publish without TAP_TOKEN fails" 0
fi

exit $fail
