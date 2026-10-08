#!/usr/bin/env bash
# Tests for changed-paths.sh against a throwaway git repository.
set -euo pipefail

script="$(cd "$(dirname "$0")" && pwd)/changed-paths.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"

git init -q -b main .
git config user.email test@example.com
git config user.name test
mkdir -p deploy/dev docs
echo one > deploy/dev/x.yaml
echo one > docs/readme
git add -A
git commit -qm base
base="$(git rev-parse HEAD)"
pattern='^(deploy/|infra/)'

failures=0
check() {
  if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1 (expected '$2', got '$3')"; failures=$((failures + 1)); fi
}
branch() { git checkout -q -B "$1" "$base"; }

branch watched; echo two > deploy/dev/x.yaml; git commit -qam w
check "a change under a watched folder" true "$(bash "$script" "$base" HEAD "$pattern")"

branch unrelated; echo two > docs/readme; git commit -qam u
check "a change elsewhere" false "$(bash "$script" "$base" HEAD "$pattern")"

branch moved; git mv deploy/dev/x.yaml docs/x.yaml; git commit -qm m
check "a file moved out of a watched folder" true "$(bash "$script" "$base" HEAD "$pattern")"

check "an empty base" true "$(bash "$script" "" HEAD "$pattern")"
check "an all-zero base (new branch)" true "$(bash "$script" 0000000000000000000000000000000000000000 HEAD "$pattern")"
check "a base missing from the clone" true "$(bash "$script" 1234567890abcdef1234567890abcdef12345678 HEAD "$pattern")"

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
