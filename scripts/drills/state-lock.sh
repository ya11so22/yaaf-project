#!/usr/bin/env bash
# A drill, not a gate: proves OpenTofu's state lock works on the local AWS (PLAN.md D22, stage 2). The foundation root keeps
# its state in S3 on Floci with `use_lockfile = true`: OpenTofu writes a `.tflock` object next to the state with a
# conditional put, so a second writer is refused instead of corrupting the state. Needs the AWS layer up (`mise run up`)
# and runs through mise (`mise exec -- bash scripts/drills/state-lock.sh`). Changes nothing: it only plans.
#
#   1. Two plans at once: the second must be refused with "Error acquiring the state lock".
#   2. The control, a planted fault: the same, with the second run's lock turned off (-lock=false), must NOT be refused.
#      If it were refused too, the refusal in 1 would prove nothing about the lock.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
ROOT="infra/environments/dev/foundation"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

ok() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; failures=$((failures + 1)); }
failures=0

tofu -chdir="$ROOT" init -input=false -no-color >/dev/null || { echo "tofu init failed: is the AWS layer up?"; exit 1; }

# Starts the first plan, waits until its lock object exists, then runs the second with the given lock flags. The bucket is
# listed unsigned, as `up` probes it: the `floci` profile exists only once `up` has built the cluster, never in a session.
race() { # second run's extra flags
  tofu -chdir="$ROOT" plan -input=false -no-color -lock-timeout=0s >"$work/first" 2>&1 &
  local first=$! end=$((SECONDS + 30))
  until aws s3 ls s3://yaaf-dev-tfstate/ --recursive --endpoint-url http://localhost:4566 --no-sign-request 2>/dev/null | grep -q '\.tflock$'; do
    [ "$SECONDS" -lt "$end" ] || { echo "the first plan never took the lock"; kill "$first" 2>/dev/null; return 2; }
    sleep 0.2
  done
  tofu -chdir="$ROOT" plan -input=false -no-color -lock-timeout=0s "$@" >"$work/second" 2>&1
  local second=$?
  wait "$first"
  return "$second"
}

race
code=$?
if [ "$code" -ne 0 ] && grep -q "Error acquiring the state lock" "$work/second"; then
  ok "a second plan is refused while the first holds the lock"
else fail "second plan with locking (exit $code): $(tail -5 "$work/second")"; fi

race -lock=false
code=$?
if [ "$code" -eq 0 ]; then ok "control: with -lock=false the second plan is not refused"
else fail "control run (exit $code): $(tail -5 "$work/second")"; fi

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
