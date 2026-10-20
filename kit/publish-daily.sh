#!/usr/bin/env bash
# Publishes the daily release from the files of a CI run (the artifact "release", unpacked in release/).
# The notes say the release is being updated until every file is in place, so they never describe files
# that are not there; if this script dies half way, that note stays and is true.
# Needs: gh (GH_TOKEN, GH_REPO), jq; GITHUB_SHA, GITHUB_RUN_ID and GITHUB_SERVER_URL from the workflow.
set -euo pipefail
: "${GH_REPO:?}" "${GITHUB_SHA:?}" "${GITHUB_RUN_ID:?}" "${GITHUB_SERVER_URL:?}"

run_url="${GITHUB_SERVER_URL}/${GH_REPO}/actions/runs/${GITHUB_RUN_ID}"
note="Being updated by ${run_url}. Until that run finishes the files here may come from two different days. If this note stays, that run failed while publishing."
if gh release view daily >/dev/null 2>&1; then
  gh release edit daily --prerelease --latest=false --notes "$note"
else
  gh release create daily --target "$GITHUB_SHA" --prerelease --latest=false \
    --title "Daily kit" --notes "$note"
fi

gh release upload daily release/*.tar.gz release/SHA256SUMS release/demo-run.log release/run-summary.json --clobber
gh api --method PATCH "repos/${GH_REPO}/git/refs/tags/daily" -f sha="$GITHUB_SHA" -F force=true

title="Daily kit, $(jq -r '.date[:10]' release/run-summary.json)"
gh release edit daily --prerelease --latest=false --title "$title" --notes-file release/notes.md
