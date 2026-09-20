#!/usr/bin/env bash
# Renders an overlay with every service image pinned to its content-hash tag on GHCR (ADR-0011).
#   usage: render-manifests.sh <overlay-dir> [rev]
# rev selects the source revision the tags are computed from (default HEAD), so rendering an older
# revision reproduces what was deployed then: that is the rollback path. Needs kubectl on PATH.
# IMAGE_PREFIX overrides the registry path (default ghcr.io/ya11so22/yaaf-project).
set -euo pipefail

overlay="$(cd "${1:?usage: render-manifests.sh <overlay-dir> [rev]}" && pwd)"
rev="${2:-HEAD}"
prefix="${IMAGE_PREFIX:-ghcr.io/ya11so22/yaaf-project}"
upstream="us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo"

here="$(cd "$(dirname "$0")" && pwd)"
root="$(git rev-parse --show-toplevel)"
cd "$root"

# A throwaway kustomization beside the overlay (not inside it, which kustomize sees as a cycle),
# so the overlay itself stays static.
work="$(mktemp -d "$(dirname "$overlay")/.render.XXXXXX")"
trap 'rm -rf "$work"' EXIT

{
  echo "apiVersion: kustomize.config.k8s.io/v1beta1"
  echo "kind: Kustomization"
  echo "resources:"
  echo "  - ../$(basename "$overlay")"
  echo "images:"
  # An empty base makes changed-services.sh list every service with its build context.
  bash "$here/changed-services.sh" "" | grep -o '"service":"[^"]*","context":"[^"]*"' |
    while IFS= read -r line; do
      svc="$(echo "$line" | sed 's/.*"service":"\([^"]*\)".*/\1/')"
      ctx="$(echo "$line" | sed 's/.*"context":"\([^"]*\)".*/\1/')"
      tag="$(bash "$here/content-tag.sh" "$ctx" "$rev")"
      echo "  - name: $upstream/$svc"
      echo "    newName: $prefix/$svc"
      echo "    newTag: $tag"
    done
} > "$work/kustomization.yaml"

kubectl kustomize "$work"
