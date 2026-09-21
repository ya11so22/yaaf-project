#!/usr/bin/env bash
# Writes the image pins in a kustomization: every service's content-hash tag on GHCR (ADR-0011,
# ADR-0013). The pins live in git so Argo CD deploys exactly what is committed, and rolling back is
# reverting the commit.
#   usage: bump-images.sh <kustomization-dir> [rev] [--verify]
# rev selects the source revision the tags are computed from (default HEAD). --verify fails if a
# tag is not on the registry, so a pin can never point at an image that was not built.
# IMAGE_PREFIX overrides the registry path (default ghcr.io/ya11so22/yaaf-project).
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

block="$begin
images:"
# An empty base makes changed-services.sh list every service with its build context.
while IFS= read -r line; do
  svc="$(echo "$line" | sed 's/.*"service":"\([^"]*\)".*/\1/')"
  ctx="$(echo "$line" | sed 's/.*"context":"\([^"]*\)".*/\1/')"
  tag="$(bash "$here/content-tag.sh" "$ctx" "$rev")"
  if $verify && ! docker manifest inspect "$prefix/$svc:$tag" >/dev/null 2>&1; then
    echo "missing on the registry: $prefix/$svc:$tag" >&2
    exit 1
  fi
  block="$block
  - name: $upstream/$svc
    newName: $prefix/$svc
    newTag: $tag"
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
