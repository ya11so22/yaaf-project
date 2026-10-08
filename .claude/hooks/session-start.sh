#!/bin/bash
# The cloud workbench (PLAN.md D30): every Claude Code cloud session starts with the locked tools and a running Docker
# engine, so `mise run check` and `mise run up` work at once. Cloud sessions only; on any other machine this does nothing.
# Synchronous on purpose: the session waits a few seconds rather than racing a command against a half-installed tool.
set -euo pipefail
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"

export PATH="$HOME/.local/bin:$PATH"
if ! command -v mise >/dev/null 2>&1; then
  # mise's own installer: one static binary into ~/.local/bin. Every other tool is then checked against mise.lock.
  curl -fsSL https://mise.run | MISE_QUIET=1 sh
fi
mise trust --quiet .
mise install --locked --quiet

# Later commands in this session find the tools without `mise exec`.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export PATH=\"$HOME/.local/bin:\$PATH\""
    echo 'eval "$(mise activate bash --shims)"'
  } >>"$CLAUDE_ENV_FILE"
fi

# The container has Docker installed but no daemon running. A restarted session worker stops it again; `mise run up`
# starts it too, so this is a convenience, not the only path.
if ! docker info >/dev/null 2>&1 && command -v dockerd >/dev/null 2>&1; then
  nohup dockerd >/tmp/dockerd.log 2>&1 &
  for _ in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 1; done
fi

# The pre-commit gate (CLAUDE.md, D9), so local commits run the same checks as CI.
git config core.hooksPath .githooks
