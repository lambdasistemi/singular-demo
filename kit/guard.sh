#!/usr/bin/env bash
# Cache-miss guard: refuse to go on if nix would compile anything beyond the
# trivial local derivations (the kit, the shell, the verifier, the unpacking of
# the two transaction tools; and the small derivations that change with every
# Singular tag: copies of the tagged source, the package list, the devnet wrapper
# script and the contract blueprints, which the project's cache does not always
# hold for a new tag and none of which compiles Haskell) and the two fixed-output
# downloads of those tools
# (release executables from GitHub, checked against a hash: downloads, not
# compiles), and the kit's static tmux with its one static library, small C
# builds of seconds. The Haskell stack takes hours to build; a missing cache entry must
# fail the run at once and name the derivation, not start compiling.
#   kit/guard.sh INSTALLABLE...     e.g.  kit/guard.sh .#kit .#kit-verify .#devShells.x86_64-linux.default
#   GUARD_ALLOW   extended regex for the derivation names that may be built
#   NIX_ARGS      extra arguments for nix (for example --store DIR --option substituters URL)
set -uo pipefail
GUARD_ALLOW=${GUARD_ALLOW:-'^(singular-demo-kit-[0-9.]+|singular-demo(-env)?|kit-verify|singular-contracts-v[0-9.]+|cardano-tx-tools-[0-9.]+|tx-(inspect|diff)-[0-9.]+-x86_64-linux-musl\.tar\.gz|source|packages\.toml|devnet|(registry|open-datum)-plutus-blueprint-[0-9.]+|open-datum-deployment-blueprint|tmux-static-x86_64-unknown-linux-musl-[0-9a-z.]+|utf8proc-static-x86_64-unknown-linux-musl-[0-9.]+)\.drv$'}
[ $# -gt 0 ] || {
  echo "usage: guard.sh INSTALLABLE..." >&2
  exit 2
}

plan=$(mktemp)
trap 'rm -f "$plan"' EXIT
# shellcheck disable=SC2086
if ! nix build --dry-run --no-link ${NIX_ARGS:-} "$@" >"$plan" 2>&1; then
  cat "$plan" >&2
  echo "guard: nix could not plan the build" >&2
  exit 2
fi

# derivations listed under "will be built"
built=$(awk '/will be built/ {on=1; next} /^[^ ]/ {on=0} on && /\.drv$/ {print $1}' "$plan")
bad=0
n=0
while IFS= read -r drv; do
  [ -n "$drv" ] || continue
  n=$((n + 1))
  if [[ "$(basename "$drv" | sed 's/^[a-z0-9]*-//')" =~ $GUARD_ALLOW ]]; then
    echo "guard: local build allowed:  $drv"
  else
    bad=$((bad + 1))
    [ "$bad" -le 20 ] && echo "guard: CACHE MISS, would build: $drv" >&2
  fi
done <<<"$built"
echo "guard: derivations to build: $n (refused: $bad)"
if [ "$bad" -gt 0 ]; then
  [ "$bad" -gt 20 ] && echo "guard: (first 20 of $bad shown)" >&2
  echo "guard: refusing. $bad derivation(s) would be compiled instead of fetched from the caches." >&2
  exit 1
fi
