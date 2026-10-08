#!/usr/bin/env bash
# Tests the account guards in .mise/tasks/sandbox against a fake `aws` (PLAN.md D46). No network, no real AWS: the fake
# answers the few calls the task makes and logs every call, so the tests can see which guard stopped the run.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/aws" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$FAKE_LOG"
case "$*" in
  "sts get-caller-identity"*"--query Account"*) [ -n "$FAKE_ACCOUNT" ] && echo "$FAKE_ACCOUNT" || exit 255 ;;
  "sts get-caller-identity"*) echo "Account $FAKE_ACCOUNT" ;;
  "agent-toolkit list-available-skills"*) printf 'skill-a\tskill-b\n' ;;
esac
EOF
chmod +x "$tmp/bin/aws"

failures=0
ok() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; failures=$((failures + 1)); }
# account signed in to, owner account ID, --account value; prints the exit code
run_task() {
  : >"$tmp/log"
  FAKE_LOG="$tmp/log" FAKE_ACCOUNT="$1" YAAF_OWNER_ACCOUNT_ID="$2" usage_account="$3" MISE_PROJECT_ROOT="$root" \
    PATH="$tmp/bin:$PATH" bash "$root/.mise/tasks/sandbox" >"$tmp/out" 2>&1 && echo 0 || echo $?
}
configured() { grep -q '^configure agent-toolkit' "$tmp/log"; }

# 1. First run: signs in afresh, shows the account, and stops before any tools.
code="$(run_task 111111111111 "" "")"
if [ "$code" = 0 ] && grep -q '^logout' "$tmp/log" && grep -q '^login --remote' "$tmp/log" && ! configured; then
  ok "first run signs in afresh and stops at the guard"
else fail "first run (exit $code): $(tr '\n' '|' <"$tmp/log")"; fi
if grep -q 'mise run sandbox --account 111111111111' "$tmp/out"; then fail "first run prints a ready-made continue command"
else ok "first run prints no ready-made continue command"; fi

# 2. The owner's own account is refused and signed out, even when --account names it.
code="$(run_task 222222222222 222222222222 222222222222)"
if [ "$code" != 0 ] && ! configured && grep -q 'logout' "$tmp/log"; then ok "owner's account refused and signed out"
else fail "owner's account (exit $code): $(tr '\n' '|' <"$tmp/log")"; fi

# 3. --account that does not match the signed-in account is refused.
code="$(run_task 111111111111 "" 333333333333)"
if [ "$code" != 0 ] && ! configured; then ok "mismatched --account refused"; else fail "mismatched --account (exit $code)"; fi

# 4. Not signed in (sign-in cancelled) fails with a message, not silently.
code="$(run_task "" "" 111111111111)"
if [ "$code" != 0 ] && grep -q 'not signed in' "$tmp/out"; then ok "no sign-in fails loudly"
else fail "no sign-in (exit $code): $(cat "$tmp/out")"; fi

# 5. The matching sandbox account goes through to the toolkit.
code="$(run_task 111111111111 999999999999 111111111111)"
if [ "$code" = 0 ] && configured && grep -q 'skill-a' "$tmp/out"; then ok "matching sandbox account sets up the toolkit"
else fail "matching account (exit $code): $(cat "$tmp/out")"; fi

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
