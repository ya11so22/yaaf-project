#!/usr/bin/env bash
# Prints a JSON array of {"service","context"} for the app services that need building.
#   usage: changed-services.sh <base-sha> <head-sha>
# Builds every service when the base is unusable (new branch, force push) or when this script
# or the build workflow changed; otherwise only services whose folder under app/src/ changed.
set -euo pipefail

base="${1:-}"
head="${2:-HEAD}"

# cartservice keeps its Dockerfile one level down; the rest have it at the service root.
context_for() {
  if [ -f "app/src/$1/Dockerfile" ]; then echo "app/src/$1"
  elif [ -f "app/src/$1/src/Dockerfile" ]; then echo "app/src/$1/src"
  fi
}

all_services() {
  for dir in app/src/*/; do
    svc="$(basename "$dir")"
    if [ -n "$(context_for "$svc")" ]; then echo "$svc"; fi
  done
}

if [ -z "$base" ] || [[ "$base" =~ ^0+$ ]] || ! git cat-file -e "$base^{commit}" 2>/dev/null; then
  services="$(all_services)"
else
  # Diff from the merge-base so changes that landed on the base branch after this one
  # forked are not counted as ours.
  fork_point="$(git merge-base "$base" "$head" 2>/dev/null || echo "$base")"
  changed="$(git diff --name-only "$fork_point" "$head")"
  if echo "$changed" | grep -qE '^\.github/(workflows/build\.yml|scripts/changed-services\.sh)$'; then
    services="$(all_services)"
  else
    services="$(echo "$changed" | sed -n 's#^app/src/\([^/]*\)/.*#\1#p' | sort -u | while read -r svc; do
      if [ -n "$(context_for "$svc")" ]; then echo "$svc"; fi
    done)"
  fi
fi

out=""
for svc in $services; do
  out="$out{\"service\":\"$svc\",\"context\":\"$(context_for "$svc")\"},"
done
echo "[${out%,}]"
