#!/usr/bin/env bash
# Bumps the dev image pins and opens (or updates) the pull request for them (ADR-0013).
#   usage: bump-pr.sh
# Env: BOT_NAME, BOT_EMAIL   commit identity (the GitHub App's bot user)
#      GH_TOKEN              the App's installation token (needed unless DRY_RUN is set)
#      BUMP_BRANCH           branch to use (default bot/bump-images: one open PR, updated in place)
#      VERIFY                "false" skips checking that each tag is on the registry (tests only)
#      DRY_RUN               non-empty: commit locally, but push nothing and open no PR
set -euo pipefail

: "${BOT_NAME:?BOT_NAME is required}" "${BOT_EMAIL:?BOT_EMAIL is required}"
branch="${BUMP_BRANCH:-bot/bump-images}"
dir="deploy/dev"
verify=(--verify)
if [ "${VERIFY:-true}" = "false" ]; then verify=(); fi

cd "$(git rev-parse --show-toplevel)"
source_sha="$(git rev-parse --short HEAD)"

bash .github/scripts/bump-images.sh "$dir" HEAD "${verify[@]}"

if git diff --quiet -- "$dir/kustomization.yaml"; then
  echo "Image pins are up to date at $source_sha; nothing to do."
  exit 0
fi

changed="$(git diff --unified=0 -- "$dir/kustomization.yaml" | grep -E '^[+-] +newTag:' | sed 's/^\([+-]\) *newTag: /\1 /')"

git checkout -q -B "$branch"
git add "$dir/kustomization.yaml"
git -c "user.name=$BOT_NAME" -c "user.email=$BOT_EMAIL" commit -q \
  -m "Bump dev image pins to the builds of $source_sha" \
  -m "$changed"
echo "Committed the pin bump on $branch."

if [ -n "${DRY_RUN:-}" ]; then
  echo "Dry run: not pushing and not opening a pull request."
  exit 0
fi

git push --force origin "$branch"

number="$(gh pr list --head "$branch" --state open --json number --jq '.[0].number // empty')"
if [ -z "$number" ]; then
  url="$(gh pr create --base main --head "$branch" \
    --title "Bump dev image pins" \
    --body "Automated by the bump-images workflow (ADR-0013). Argo CD deploys the pins on merge; reverting this PR rolls them back.")"
  number="${url##*/}"
  echo "Opened $url"
else
  echo "Updated pull request #$number"
fi

# Merges itself when the required checks pass. Needs "Allow auto-merge" in the repository settings.
gh pr merge "$number" --auto --merge
