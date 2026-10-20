#!/usr/bin/env bash
# Smoke test of the nix shell. Run it inside the shell:  nix develop --command kit/smoke.sh
# The programs resolve and start, the blueprint is the expected file, the genesis directory is there.
set -euo pipefail
blueprint_sha256=89ecfeb0642a45dc57188a3f811e7e0fcaa6007b4abac0997e5491f9b53960c8
for p in singular open-datum devnet tx-inspect tx-diff jq; do
  printf '%-12s %s\n' "$p" "$(command -v "$p" || {
    echo "not on the PATH: $p" >&2
    exit 1
  })"
done
singular --help >/dev/null
open-datum --help >/dev/null
tx-inspect --help >/dev/null
# tx-diff has no --help: with no arguments it prints its usage line
(tx-diff 2>&1 || true) | grep -q "^Usage: tx-diff"
# shellcheck disable=SC2154  # blueprint is set by the shell
got=$(sha256sum "$blueprint" | cut -d' ' -f1)
echo "blueprint    $blueprint"
echo "sha256       $got"
[ "$got" = "$blueprint_sha256" ] || {
  echo "blueprint checksum differs from $blueprint_sha256" >&2
  exit 1
}
[ -n "$(ls "$E2E_GENESIS_DIR")" ] || {
  echo "genesis directory is empty: $E2E_GENESIS_DIR" >&2
  exit 1
}
echo "genesis      $E2E_GENESIS_DIR ($(find "$E2E_GENESIS_DIR" -mindepth 1 -maxdepth 1 | wc -l) files)"
echo "smoke: ok"
