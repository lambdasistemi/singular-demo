#!/usr/bin/env bash
# The daily run's summary, from the facts the run collected.
#   kit/summary.sh json    write run-summary.json to stdout
#   kit/summary.sh notes   write the release notes to stdout (reads run-summary.json from SUMMARY)
# Environment for json: DIST (directory with the tarball and SHA256SUMS), LOG (the good container run log),
#   IMAGE_REF, IMAGE_DIGEST, RUN_URL, NIX_VERSION, RUNNER_IMAGE
# Environment for notes: SUMMARY (path of run-summary.json)
set -euo pipefail
case "${1:?json|notes}" in
  json)
    tarball=$(ls "$DIST"/*.tar.gz); sha=$(cut -d' ' -f1 "$DIST/SHA256SUMS")
    version=$(tar xzf "$tarball" --wildcards '*/VERSION' -O)
    steps=$(grep -c '^━━ Step [0-9]* of 16 ' "$LOG")
    passed=false; grep -q '^All 16 steps passed\.' "$LOG" && passed=true
    jq -n \
      --arg date "$(date -u +%FT%TZ)" --arg run "$RUN_URL" \
      --arg tag "$(sed -n 's/^singular //p' <<< "$version")" \
      --arg commit "$(sed -n 's/^commit //p' <<< "$version")" \
      --arg node "$(sed -n 's/^cardano-node //p' <<< "$version")" \
      --arg nix "$NIX_VERSION" --arg runner "$RUNNER_IMAGE" \
      --arg image "$IMAGE_REF" --arg digest "$IMAGE_DIGEST" \
      --arg tarball "$(basename "$tarball")" --arg sha "$sha" \
      --argjson steps "$steps" --argjson passed "$passed" \
      '{date: $date, run_url: $run, singular_tag: $tag, singular_commit: $commit, cardano_node: $node,
        nix_version: $nix, runner_image: $runner, container_image: $image, container_image_digest: $digest,
        tarball: $tarball, tarball_sha256: $sha, steps_passed: $steps, steps_total: 16,
        result: (if $passed and $steps == 16 then "pass" else "fail" end)}'
    ;;
  notes)
    jq -r '(.tarball | rtrimstr(".tar.gz")) as $dir | "Daily rebuild of the Ubuntu kit for Singular \(.singular_tag), rebuilt and run from scratch on \(.date).\n\n"
      + "| | |\n|---|---|\n"
      + "| result | \(.result): \(.steps_passed) of \(.steps_total) steps passed in a clean Ubuntu 24.04 container |\n"
      + "| Singular | \(.singular_tag), commit \(.singular_commit) |\n"
      + "| cardano-node | \(.cardano_node) |\n"
      + "| run | \(.run_url) |\n"
      + "| tarball | \(.tarball) |\n"
      + "| sha256 | \(.tarball_sha256) |\n"
      + "| container image | \(.container_image_digest) |\n"
      + "| nix | \(.nix_version) |\n"
      + "| runner | \(.runner_image) |\n\n"
      + "This release is overwritten every day; the fixed release is v0.12.0.\n\n"
      + "Use: download the tarball and SHA256SUMS, then\n\n"
      + "```\nsha256sum -c SHA256SUMS\ntar xzf \(.tarball)\ncd \($dir)\n./demo.sh\n```\n\n"
      + "demo-run.log is the full output of the run; run-summary.json holds the table above."' "${SUMMARY:?run-summary.json}"
    ;;
  *) echo "usage: summary.sh json|notes" >&2; exit 2;;
esac
