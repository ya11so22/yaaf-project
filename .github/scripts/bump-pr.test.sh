#!/usr/bin/env bash
# Tests bump-pr.sh in a throwaway clone, in dry-run mode: nothing is pushed and no PR is opened.
set -euo pipefail

src="$(git rev-parse --show-toplevel)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone -q --no-hardlinks "$src" "$tmp/repo"
cd "$tmp/repo"
git config user.email test@example.com
git config user.name test
git config core.autocrlf false
# The clone starts from the last commit, not the working tree, so carry over the scripts under test.
cp "$src"/.github/scripts/*.sh .github/scripts/
# Normalise line endings: a Windows working tree has CRLF, the script writes LF, and CI is Linux.
tr -d '\r' < "$src/deploy/dev/kustomization.yaml" > deploy/dev/kustomization.yaml
git add -A && git commit -qm "test baseline" --allow-empty

# Start from pins that are current for this clone, whatever state the real repository is in. The real
# pins go stale on purpose whenever app code changes, until the bump PR lands, so a test that relied
# on them would fail on exactly the change the bump workflow exists for.
VERIFY=false bash .github/scripts/bump-images.sh deploy/dev HEAD
git commit -qam "baseline: pins current" --allow-empty

export BOT_NAME="test-bot[bot]" BOT_EMAIL="1+test-bot[bot]@users.noreply.github.com" DRY_RUN=1 VERIFY=false

failures=0
ok()   { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; failures=$((failures + 1)); }

# 1. Pins already current: nothing happens.
out="$(bash .github/scripts/bump-pr.sh)"
if echo "$out" | grep -q "up to date"; then ok "no change when the pins are current"; else fail "expected 'up to date': $out"; fi
if [ "$(git rev-parse --abbrev-ref HEAD)" = "bot/bump-images" ]; then fail "no branch should be created"; else ok "no branch created when nothing changed"; fi

# 2. A stale pin: a bump commit is made by the bot on the bump branch.
sed -i '0,/newTag: content-[0-9a-f]\{12\}/s//newTag: content-000000000000/' deploy/dev/kustomization.yaml
git commit -qam "make a pin stale"
out="$(bash .github/scripts/bump-pr.sh)"
if [ "$(git rev-parse --abbrev-ref HEAD)" = "bot/bump-images" ]; then ok "bump branch created"; else fail "expected bot/bump-images, on $(git rev-parse --abbrev-ref HEAD)"; fi
if [ "$(git log -1 --format=%an)" = "test-bot[bot]" ]; then ok "commit authored by the bot"; else fail "author was $(git log -1 --format=%an)"; fi
if git log -1 --format=%B | grep -q '^- content-000000000000'; then ok "commit message lists the old pin"; else fail "commit message: $(git log -1 --format=%B)"; fi
if git diff --name-only HEAD~1 | grep -qx 'deploy/dev/kustomization.yaml' && [ "$(git diff --name-only HEAD~1 | wc -l)" -eq 1 ]; then ok "only the kustomization changed"; else fail "unexpected files: $(git diff --name-only HEAD~1)"; fi
if echo "$out" | grep -q "not pushing"; then ok "dry run pushes nothing"; else fail "dry run output: $out"; fi

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
