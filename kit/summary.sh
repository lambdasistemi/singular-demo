#!/usr/bin/env bash
# The daily run's summary, from the facts the run collected.
#   kit/summary.sh json    write run-summary.json to stdout
#   kit/summary.sh notes   write the daily release notes to stdout (reads run-summary.json from SUMMARY)
#   kit/summary.sh release-notes   write the notes of a numbered release to stdout (the same file)
# Environment for json: DIST (directory with the tarball and SHA256SUMS), LOG (the good container run log),
#   IMAGE_REF, IMAGE_DIGEST, RUN_URL, NIX_VERSION, RUNNER_IMAGE, KIT_COMMIT (this repository's commit)
# Environment for notes and release-notes: SUMMARY (path of run-summary.json)
set -euo pipefail
case "${1:?json|notes}" in
  json)
    tarball=$(ls "$DIST"/*.tar.gz)
    sha=$(cut -d' ' -f1 "$DIST/SHA256SUMS")
    folder=$(basename "$tarball" .tar.gz)
    version=$(tar xzf "$tarball" "$folder/VERSION" -O)
    steps=$(sed -n 's/^Lifecycle steps passed: \([0-9]*\)\/16$/\1/p' "$LOG" | tail -1)
    steps=${steps:-0}
    passed=false
    grep -q '^All 16 steps passed\.' "$LOG" && passed=true
    jq -n \
      --arg date "$(date -u +%FT%TZ)" --arg run "$RUN_URL" \
      --arg tag "$(sed -n 's/^singular //p' <<<"$version")" \
      --arg release "$(sed -n 's/^kit //p' <<<"$version")" \
      --arg commit "$(sed -n 's/^commit //p' <<<"$version")" \
      --arg node "$(sed -n 's/^cardano-node //p' <<<"$version")" \
      --arg nix "$NIX_VERSION" --arg runner "$RUNNER_IMAGE" --arg kit "${KIT_COMMIT:-}" \
      --arg image "$IMAGE_REF" --arg digest "$IMAGE_DIGEST" \
      --arg tarball "$(basename "$tarball")" --arg sha "$sha" \
      --argjson steps "$steps" --argjson passed "$passed" \
      '{date: $date, run_url: $run, kit_commit: $kit, kit_release: $release, singular_tag: $tag, singular_commit: $commit, cardano_node: $node,
        nix_version: $nix, runner_image: $runner, container_image: $image, container_image_digest: $digest,
        tarball: $tarball, tarball_sha256: $sha, steps_passed: $steps, steps_total: 16,
        result: (if $passed and $steps == 16 then "pass" else "fail" end)}'
    ;;
  notes)
    jq -r '(.tarball | rtrimstr(".tar.gz")) as $dir | "Daily rebuild of the Ubuntu kit \(.kit_release) for Singular \(.singular_tag), rebuilt and run from scratch on \(.date).\n\n"
      + "| | |\n|---|---|\n"
      + "| result | \(.result): \(.steps_passed) of \(.steps_total) steps passed in a clean Ubuntu 24.04 container |\n"
      + "| kit | \(.kit_release) |\n"
      + "| Singular | \(.singular_tag), commit \(.singular_commit) |\n"
      + "| cardano-node | \(.cardano_node) |\n"
      + "| run | \(.run_url) |\n"
      + "| tarball | \(.tarball) |\n"
      + "| sha256 | \(.tarball_sha256) |\n"
      + "| container image | \(.container_image_digest) |\n"
      + "| nix | \(.nix_version) |\n"
      + "| runner | \(.runner_image) |\n\n"
      + "This release is overwritten every day; the numbered releases, such as \(.kit_release), are fixed.\n\n"
      + "Use: download the tarball and SHA256SUMS, then\n\n"
      + "```\nsha256sum -c SHA256SUMS\ntar xzf \(.tarball)\ncd \($dir)\n./demo.sh\n```\n\n"
      + "demo-run.log is the full output of the run; run-summary.json holds the table above."' "${SUMMARY:?run-summary.json}"
    ;;
  release-notes)
    jq -r '(.tarball | rtrimstr(".tar.gz")) as $dir | "Demo 1 kit \(.kit_release) for Ubuntu 24.04 on x86_64, from Singular \(.singular_tag). No Nix needed.\n\n"
      + "Contents: `singular`, `open-datum`, `devnet` and the `cardano-node` \(.cardano_node) it starts, the transaction tools `tx-inspect` and `tx-diff`, `jq` and `curl`, with their libraries and the C library, the contracts (`plutus.json`, same bytes as the release archive), the devnet genesis, and `demo.sh`, the annotated 16-step journey on a private devnet.\n\n"
      + "Built from the Singular \(.singular_tag) release (commit \(.singular_commit)) by `nix build .#kit` from the lock file of this repository at commit \(.kit_commit), built and proved by \(.run_url). Run in a clean `ubuntu:24.04` container with no `/nix`: the demo run is \(.result): \(.steps_passed) of \(.steps_total) steps. Not independently audited.\n\n"
      + "Use: unpack the tarball, `cd` into it, run `./demo.sh`. The steps are in the README of this repository.\n\n"
      + "sha256 of `\(.tarball)`: `\(.tarball_sha256)`\n\n"
      + "demo-run.log is the full output of the run; run-summary.json holds the facts above."' "${SUMMARY:?run-summary.json}"
    ;;
  *)
    echo "usage: summary.sh json|notes|release-notes" >&2
    exit 2
    ;;
esac
