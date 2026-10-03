#!/usr/bin/env bash
# Writes the image pins in a kustomization: every service's content-hash tag on GHCR, and with --verify its digest
# (ADR-0023, ADR-0024). The pins live in git so Argo CD deploys exactly what is committed.
#   usage: bump-images.sh <kustomization-dir> [rev] [--verify]
# rev selects the source revision the tags are computed from (default HEAD). --verify looks each tag up on the registry
# and pins its digest too (rendered as name:tag@sha256:...), so a pin can never point at an image that was not built,
# and a tag moved later cannot change what runs.
# IMAGE_PREFIX overrides the registry path (default ghcr.io/ya11so22/yaaf-project).
# DIGEST_RESOLVER overrides the lookup: a command given image:tag that prints its digest (tests use a stub).
set -euo pipefail

dir="${1:?usage: bump-images.sh <kustomization-dir> [rev] [--verify]}"
rev="HEAD"
verify=false
shift
for arg in "$@"; do
  if [ "$arg" = "--verify" ]; then verify=true; else rev="$arg"; fi
done

prefix="${IMAGE_PREFIX:-ghcr.io/ya11so22/yaaf-project}"
upstream="us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo"
here="$(cd "$(dirname "$0")" && pwd)"
file="$dir/kustomization.yaml"
begin="# BEGIN image pins (written by .github/scripts/bump-images.sh; do not edit by hand)"
end="# END image pins"

grep -qF "$begin" "$file" && grep -qF "$end" "$file" || {
  echo "$file has no image-pin markers" >&2
  exit 1
}

digest_of() {
  local out
  if [ -n "${DIGEST_RESOLVER:-}" ]; then
    out="$("$DIGEST_RESOLVER" "$1")"
  else
    out="$(docker buildx imagetools inspect "$1" --format '{{json .Manifest.Digest}}' 2>/dev/null | tr -d '"')"
  fi
  [[ "$out" =~ ^sha256:[0-9a-f]{64}$ ]] || return 1
  echo "$out"
}

block="$begin
images:"
# An empty base makes changed-services.sh list every service with its build context.
while IFS= read -r line; do
  svc="$(echo "$line" | sed 's/.*"service":"\([^"]*\)".*/\1/')"
  ctx="$(echo "$line" | sed 's/.*"context":"\([^"]*\)".*/\1/')"
  tag="$(bash "$here/content-tag.sh" "$ctx" "$rev")"
  block="$block
  - name: $upstream/$svc
    newName: $prefix/$svc
    newTag: $tag"
  if $verify; then
    digest="$(digest_of "$prefix/$svc:$tag")" || { echo "missing on the registry: $prefix/$svc:$tag" >&2; exit 1; }
    block="$block
    digest: $digest"
  fi
done < <(bash "$here/changed-services.sh" "" | grep -o '"service":"[^"]*","context":"[^"]*"')
block="$block
$end"

# Replace everything between the markers, keeping the rest of the file untouched.
tmp="$(mktemp)"
awk -v block="$block" -v begin="$begin" -v end="$end" '
  index($0, begin) { print block; skipping = 1; next }
  index($0, end)   { skipping = 0; next }
  !skipping        { print }
' "$file" > "$tmp"
cat "$tmp" > "$file"
rm -f "$tmp"
