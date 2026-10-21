#!/usr/bin/env bash
# Checks the files of a CI run before the numbered release is made from them:
# the tag names the kit that was built (the Singular release and the kit's revision, as in v0.14.0-1), the demo run
# passed, the checksum holds.
#   kit/check-release.sh TAG        run in the directory that holds release/
set -euo pipefail
tag=${1:?usage: kit/check-release.sh TAG}

built=$(jq -r .kit_release release/run-summary.json)
[ "$built" = "$tag" ] || {
  echo "::error::the tag is $tag but the kit built is release $built (Singular release and kit revision)" >&2
  exit 1
}
[ "$(jq -r .result release/run-summary.json)" = pass ] || {
  echo "::error::the demo run did not pass" >&2
  exit 1
}
test -f "release/singular-demo-$tag-x86_64-linux.tar.gz"
(cd release && sha256sum -c SHA256SUMS)
