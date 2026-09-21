#!/usr/bin/env bash
# Tests that the dev overlay renders with every service pinned to a content tag on GHCR.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
script=".github/scripts/render-manifests.sh"
out="$(IMAGE_PREFIX=ghcr.io/example/repo bash "$script" deploy/dev)"

failures=0
ok()   { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; failures=$((failures + 1)); }

images="$(echo "$out" | grep -o 'image: [^ ]*' | sed 's/image: //' | sort -u)"

if echo "$images" | grep -q 'us-central1-docker.pkg.dev'; then fail "no upstream registry images remain"; else ok "no upstream registry images remain"; fi
if echo "$images" | grep -q 'loadgenerator'; then fail "load generator excluded"; else ok "load generator excluded"; fi

ours="$(echo "$images" | grep -c '^ghcr.io/example/repo/[a-z]*:content-[0-9a-f]\{12\}$' || true)"
if [ "$ours" -eq 10 ]; then ok "10 services pinned to content tags"; else fail "expected 10 pinned services, got $ours"; fi

deployments="$(echo "$out" | grep -c '^kind: Deployment' || true)"
if [ "$deployments" -eq 11 ]; then ok "10 services and redis are deployed"; else fail "expected 11 deployments, got $deployments"; fi

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
