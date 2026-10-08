#!/bin/bash
# The cloud workbench (PLAN.md D30): every Claude Code cloud session starts with the locked tools, so `mise run check`
# works at once. Docker is started by `mise run up`, the only thing that needs it. Cloud sessions only; on any other
# machine this does nothing.
# Synchronous on purpose: the session waits a few seconds rather than racing a command against a half-installed tool.
set -euo pipefail
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"

export PATH="$HOME/.local/bin:$PATH"
if ! command -v mise >/dev/null 2>&1; then
  # mise's own installer, pinned to a release past the 7-day cooldown (PLAN.md D24); it checks the download's SHA-256.
  # Bump by hand. Every other tool is then checked against mise.lock.
  curl -fsSL https://mise.run | MISE_VERSION=v2026.9.16 MISE_QUIET=1 sh
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

# The pre-commit gate (PLAN.md D9), so local commits run the same checks as CI.
git config core.hooksPath .githooks
