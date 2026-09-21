#!/usr/bin/env bash
# Tests for content-tag.sh against a throwaway git repository.
set -euo pipefail

script="$(cd "$(dirname "$0")" && pwd)/content-tag.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"

git init -q -b main .
git config user.email test@example.com
git config user.name test
git config core.autocrlf false

mkdir -p app/src/a app/src/b/src
echo one > app/src/a/file
echo one > app/src/b/src/file
git add -A
git commit -qm base

failures=0
check() {
  if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1 (expected '$2', got '$3')"; failures=$((failures + 1)); fi
}
differs() {
  if [ "$2" != "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1 (both '$2')"; failures=$((failures + 1)); fi
}

a1="$("$script" app/src/a)"
b1="$("$script" app/src/b/src)"

case "$a1" in content-????????????) echo "ok   - tag format" ;; *) echo "FAIL - tag format: $a1"; failures=$((failures + 1)) ;; esac
check "trailing slash accepted" "$a1" "$("$script" app/src/a/)"

echo two > app/src/b/src/file
git commit -qam "change b"
check "unrelated change keeps the tag" "$a1" "$("$script" app/src/a)"
differs "own change alters the tag" "$b1" "$("$script" app/src/b/src)"
check "earlier revision still resolves" "$b1" "$("$script" app/src/b/src HEAD~1)"

echo one > app/src/b/src/file
git commit -qam "revert b"
check "same content gives the same tag" "$b1" "$("$script" app/src/b/src)"

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
