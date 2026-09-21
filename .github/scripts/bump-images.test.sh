#!/usr/bin/env bash
# Tests bump-images.sh against a copy of the dev overlay, and that the committed pins render.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
script=".github/scripts/bump-images.sh"

# The overlay is copied beside the original so its relative paths into app/ still resolve.
work="deploy/.bump-test.$$"
trap 'rm -rf "$work"' EXIT
mkdir "$work"
cp deploy/dev/*.yaml "$work/"

failures=0
ok()   { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; failures=$((failures + 1)); }

IMAGE_PREFIX=ghcr.io/example/repo bash "$script" "$work"
pins="$(grep -c 'newTag: content-[0-9a-f]\{12\}$' "$work/kustomization.yaml" || true)"
if [ "$pins" -eq 12 ]; then ok "all 12 buildable services pinned to content tags"; else fail "expected 12 pins, got $pins"; fi

cp "$work/kustomization.yaml" "$work/first.yaml"
IMAGE_PREFIX=ghcr.io/example/repo bash "$script" "$work"
if cmp -s "$work/first.yaml" "$work/kustomization.yaml"; then ok "idempotent"; else fail "second run changed the file"; fi

if grep -q 'components/without-loadgenerator' "$work/kustomization.yaml"; then ok "content outside the markers untouched"; else fail "content outside the markers changed"; fi

rendered="$(kubectl kustomize "$work")"
if echo "$rendered" | grep -q 'us-central1-docker.pkg.dev'; then fail "no upstream registry images remain"; else ok "no upstream registry images remain"; fi
if echo "$rendered" | grep 'image:' | grep -q 'loadgenerator'; then fail "load generator excluded"; else ok "load generator excluded"; fi

# The committed pins must be renderable and point only at our registry (or redis-cart's cache).
committed="$(kubectl kustomize deploy/dev | grep -o 'image: [^ ]*' | sed 's/image: //' | sort -u)"
if echo "$committed" | grep -v '^ghcr.io/ya11so22/yaaf-project/[a-z]*:content-[0-9a-f]\{12\}$' | grep -qv '^redis:alpine$'; then
  fail "committed pins: unexpected image"
else
  ok "committed pins render to our registry images only"
fi

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
