#!/usr/bin/env bash
# Rewrites the registry's windows where the tutorial sets them, the line `process_ms=N; retract_ms=N` of the
# create step, with PROCESS_TIME_MS and RETRACT_TIME_MS; with neither set it changes nothing. A run that plays a
# copy of the tutorial with it waits less on the chain (the least windows the registry allows are 60000 and 30000).
# When the line already reads the settings (`process_ms=${PROCESS_TIME_MS:-180000}; ...`), there is nothing to
# rewrite: the environment controls the windows at runtime, so it succeeds without changing anything.
#   short-windows.sh FILE_OR_DIR...   rewrites in place; fails when a value is set and no file has the line
set -euo pipefail
[ -n "${PROCESS_TIME_MS:-}${RETRACT_TIME_MS:-}" ] || exit 0
case "${PROCESS_TIME_MS:-0}${RETRACT_TIME_MS:-0}" in *[!0-9]*)
  echo "short-windows.sh: PROCESS_TIME_MS and RETRACT_TIME_MS must be whole numbers of milliseconds" >&2
  exit 2
  ;;
esac
line='^process_ms=[0-9]+; retract_ms=[0-9]+$'
param='^process_ms=\$\{PROCESS_TIME_MS:-[0-9]+\}; retract_ms=\$\{RETRACT_TIME_MS:-[0-9]+\}$'
mapfile -t files < <(grep -rlE "$line" "$@" || true)
if [ "${#files[@]}" -eq 0 ]; then
  mapfile -t pfiles < <(grep -rlE "$param" "$@" || true)
  [ "${#pfiles[@]}" -gt 0 ] || {
    echo "short-windows.sh: no line process_ms=N; retract_ms=N in $*" >&2
    exit 1
  }
  echo "windows: parameterized (PROCESS_TIME_MS/RETRACT_TIME_MS at runtime) in ${#pfiles[@]} file(s)"
  exit 0
fi
[ -z "${PROCESS_TIME_MS:-}" ] || sed -i -E "s/^process_ms=[0-9]+;/process_ms=$PROCESS_TIME_MS;/" "${files[@]}"
[ -z "${RETRACT_TIME_MS:-}" ] || sed -i -E "s/; retract_ms=[0-9]+$/; retract_ms=$RETRACT_TIME_MS/" "${files[@]}"
echo "windows: $(grep -hE "$line" "${files[@]}" | sort -u) in ${#files[@]} file(s)"
