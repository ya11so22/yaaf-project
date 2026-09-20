#!/usr/bin/env bash
# Tests for changed-services.sh against a throwaway git repository.
set -euo pipefail

script="$(cd "$(dirname "$0")" && pwd)/changed-services.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"

git init -q -b main .
git config user.email test@example.com
git config user.name test
git config core.autocrlf false

mkdir -p app/src/a app/src/b app/src/cart/src app/src/nodocker docs .github/workflows .github/scripts
touch app/src/a/Dockerfile app/src/b/Dockerfile app/src/cart/src/Dockerfile app/src/nodocker/file docs/x
touch .github/workflows/build.yml .github/scripts/changed-services.sh
git add -A
git commit -qm base
base="$(git rev-parse HEAD)"

ALL='[{"service":"a","context":"app/src/a"},{"service":"b","context":"app/src/b"},{"service":"cart","context":"app/src/cart/src"}]'
failures=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok   - $name"
  else
    echo "FAIL - $name"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    failures=$((failures + 1))
  fi
}

commit_change() { echo "$RANDOM" >> "$1"; git add -A; git commit -qm "change $1"; }

check "empty base builds everything" "$ALL" "$(bash "$script" "" HEAD)"
check "all-zero base (new branch) builds everything" "$ALL" "$(bash "$script" 0000000000000000000000000000000000000000 HEAD)"
check "unknown base (force push) builds everything" "$ALL" "$(bash "$script" deadbeefdeadbeefdeadbeefdeadbeefdeadbeef HEAD)"

commit_change docs/x
check "docs-only change builds nothing" "[]" "$(bash "$script" "$base" HEAD)"

commit_change app/src/a/Dockerfile
check "one service changed" '[{"service":"a","context":"app/src/a"}]' "$(bash "$script" "$base" HEAD)"

commit_change app/src/cart/src/Dockerfile
check "nested Dockerfile uses its own context" \
  '[{"service":"a","context":"app/src/a"},{"service":"cart","context":"app/src/cart/src"}]' "$(bash "$script" "$base" HEAD)"

commit_change app/src/nodocker/file
check "folder without a Dockerfile is ignored" \
  '[{"service":"a","context":"app/src/a"},{"service":"cart","context":"app/src/cart/src"}]' "$(bash "$script" "$base" HEAD)"

before_wf="$(git rev-parse HEAD)"
commit_change .github/workflows/build.yml
check "workflow change builds everything" "$ALL" "$(bash "$script" "$before_wf" HEAD)"

before_sc="$(git rev-parse HEAD)"
commit_change .github/scripts/changed-services.sh
check "script change builds everything" "$ALL" "$(bash "$script" "$before_sc" HEAD)"

# A branch forked earlier must not pick up changes that landed on main afterwards.
git checkout -q -b feature "$base"
commit_change app/src/a/Dockerfile
git checkout -q main
commit_change app/src/b/Dockerfile
check "changes that landed on the base after forking are not counted" \
  '[{"service":"a","context":"app/src/a"}]' "$(bash "$script" main feature)"

if [ "$failures" -ne 0 ]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
