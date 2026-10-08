#!/usr/bin/env bash
# Prints "true" when a change touches any path matching a pattern, "false" otherwise. Shared by the infra and environment
# workflows, so path-based gating is one tested definition (PLAN.md D24).
#   usage: changed-paths.sh <base-sha> <head-sha> <extended regex over repository paths>
# Unsure means "true": an unusable base (new branch, force push, a commit missing from the clone) or a failing diff runs
# the work rather than skipping it, because a skipped check that should have run passes silently.
set -euo pipefail

base="${1:-}"
head="${2:-HEAD}"
pattern="${3:?usage: changed-paths.sh <base> <head> <regex>}"

if [ -z "$base" ] || [[ "$base" =~ ^0+$ ]] || ! git cat-file -e "$base^{commit}" 2>/dev/null; then
  echo true
  exit 0
fi
# From the merge-base, so changes that landed on the base branch after this one forked are not counted as ours.
# --no-renames: a moved file is listed under its old path too, so moving something out of a watched folder counts.
fork_point="$(git merge-base "$base" "$head" 2>/dev/null || echo "$base")"
if ! changed="$(git diff --no-renames --name-only "$fork_point" "$head")"; then
  echo true
  exit 0
fi
if printf '%s\n' "$changed" | grep -qE "$pattern"; then echo true; else echo false; fi
