#!/usr/bin/env bash
# Prints the content-hash image tag for a build context (ADR-0011).
#   usage: content-tag.sh <context-dir> [rev]
# The tag is the git tree hash of the directory, so it changes only when the files the image is
# built from change. Unchanged services keep their tag across commits, which lets a deploy resolve
# every service to an image that already exists.
set -euo pipefail

context="${1:?usage: content-tag.sh <context-dir> [rev]}"
rev="${2:-HEAD}"

tree="$(git rev-parse "$rev:${context%/}")"
echo "content-${tree:0:12}"
