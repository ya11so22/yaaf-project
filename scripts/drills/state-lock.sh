#!/usr/bin/env bash
# A drill, not a gate: proves OpenTofu's state lock works on the local AWS (PLAN.md D22, stage 2). The foundation root keeps
# its state in S3 on Floci with `use_lockfile = true`: OpenTofu writes a `.tflock` object next to the state with a
# conditional put, so a second writer is refused instead of corrupting the state. Needs the AWS layer up (`mise run up`)
# and runs through mise (`mise exec -- bash scripts/drills/state-lock.sh`). Changes nothing: it only reads and plans.
#
# The lock holder is `tofu console`, which holds the state lock for as long as it runs; fed from a FIFO, it runs until
# the drill closes the FIFO. That makes the overlap certain rather than a race against a fast plan, and it is checked.
#   1. While the console holds the lock, a plan must be refused with "Error acquiring the state lock".
#   2. The control, a planted fault: the same plan with its lock turned off (-lock=false) must NOT be refused, so the
#      refusal in 1 comes from the lock and nothing else.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
ROOT="infra/environments/dev/foundation"
LOCK_KEY="foundation/terraform.tfstate.tflock"
work="$(mktemp -d)"
holder=""
cleanup() {
  exec 3>&- 2>/dev/null
  [ -z "$holder" ] || { kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null; }
  rm -rf "$work"
}
trap cleanup EXIT

ok() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; failures=$((failures + 1)); }
failures=0
# Unsigned, as `up` probes the bucket: the `floci` profile exists only once `up` has built the cluster, never in a session.
lock_exists() {
  aws s3 ls "s3://yaaf-dev-tfstate/$LOCK_KEY" --endpoint-url http://localhost:4566 --no-sign-request >/dev/null 2>&1
}
second_plan() { # extra flags
  tofu -chdir="$ROOT" plan -input=false -no-color -lock-timeout=0s "$@" >"$work/second" 2>&1
}

tofu -chdir="$ROOT" init -input=false -no-color >/dev/null || { echo "tofu init failed: is the AWS layer up?"; exit 1; }
# A lock left by an interrupted run would refuse the plan below without any lock being taken here: a false pass.
if lock_exists; then echo "a lock is already held ($LOCK_KEY): finish or unlock that run first"; exit 1; fi

mkfifo "$work/in"
tofu -chdir="$ROOT" console -no-color <"$work/in" >"$work/holder" 2>&1 &
holder=$!
exec 3>"$work/in"
end=$((SECONDS + 60))
until lock_exists; do
  kill -0 "$holder" 2>/dev/null || { echo "the console exited without taking the lock: $(tail -5 "$work/holder")"; exit 1; }
  [ "$SECONDS" -lt "$end" ] || { echo "the console never took the lock"; exit 1; }
  sleep 0.5
done

second_plan
code=$?
if ! kill -0 "$holder" 2>/dev/null; then fail "the lock holder exited during the plan, so nothing overlapped"
elif [ "$code" -ne 0 ] && grep -q "Error acquiring the state lock" "$work/second"; then
  ok "a plan is refused while another process holds the lock"
else fail "plan with locking (exit $code): $(tail -5 "$work/second")"; fi

second_plan -lock=false
code=$?
if ! kill -0 "$holder" 2>/dev/null; then fail "the lock holder exited during the control, so nothing overlapped"
elif [ "$code" -eq 0 ]; then ok "control: with -lock=false the same plan is not refused"
else fail "control run (exit $code): $(tail -5 "$work/second")"; fi

# Closing the FIFO ends the console, which releases the lock.
exec 3>&-
wait "$holder" || fail "the lock holder failed: $(tail -5 "$work/holder")"
holder=""
if lock_exists; then fail "the lock was not released ($LOCK_KEY)"; else ok "the lock is released afterwards"; fi

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
