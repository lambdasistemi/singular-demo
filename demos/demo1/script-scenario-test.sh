#!/usr/bin/env bash
# Runs the generated "script" scenario the way Killercoda runs it, on a clean Ubuntu with no Nix:
#   node demos/demo1/killercoda.js /tmp/out
#   docker run --rm -v /tmp/out/killercoda/demo1-script:/scenario:ro -v "$PWD":/repo:ro ubuntu:24.04 \
#     bash /repo/demos/demo1/script-scenario-test.sh /scenario
# The setup runs, then the command of the first step (without the final "follow the log"), and the log
# must end with all 16 steps passed. KIT_BASE=file:///dir tests a kit that is not released yet.
set -u
scenario=$(cd "${1:?usage: script-scenario-test.sh SCENARIO_DIR}" && pwd)
export HOME=/root
cd "$HOME" || exit 1
if ! command -v curl >/dev/null; then apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null; fi
[ -z "${KIT_BASE:-}" ] || export PLAY_KIT_BASE="$KIT_BASE"
if ! bash "$scenario/intro/background.sh" >/tmp/background.log 2>&1 || [ ! -f /tmp/finished ]; then
  echo "FAIL  intro/background.sh did not finish"
  tail -8 /tmp/background.log
  exit 1
fi
echo "ok    intro/background.sh finished"
cmd=$(awk '/^```bash$/ {on=1; next} /^```\{\{exec\}\}$/ {exit} on' "$scenario/step1/text.md" | sed 's/ *; *tail -n +1 -f demo.log$//')
case "$cmd" in *"./demo.sh"*) ;; *)
  echo "FAIL  the first block of step1 does not run demo.sh: $cmd"
  exit 1
  ;;
esac
bash -c "$cmd" || {
  echo "FAIL  the step's command failed"
  exit 1
}
kit=$(find "$HOME" -maxdepth 1 -type d -name 'singular-demo-*-linux' | head -1)
for _ in $(seq 1 360); do
  grep -q '^All 16 steps passed' "$kit/demo.log" 2>/dev/null && break
  grep -q 'The run did not finish' "$kit/demo.log" 2>/dev/null && break
  sleep 5
done
if grep -q '^All 16 steps passed' "$kit/demo.log"; then echo "ok    the log ends with: $(grep '^All 16 steps passed' "$kit/demo.log")"; else
  echo "FAIL  the script did not pass:"
  tail -15 "$kit/demo.log"
  exit 1
fi
if grep -q '60 seconds' "$kit/demo.log"; then echo "ok    the windows were the short ones (60 seconds)"; else
  echo "FAIL  the windows were not set to 60 seconds"
  exit 1
fi
if pgrep -f 'cardano-node|devnet' >/dev/null; then
  echo "FAIL  the chain is still running after the script"
  exit 1
else echo "ok    the chain was stopped by the script"; fi
echo "RESULT: PASS"
