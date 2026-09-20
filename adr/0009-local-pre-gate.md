# ADR-0009: A shared local pre-gate, with CI as the source of truth

**Status:** accepted
**Date:** 2026-09-20

## Context

Every check so far ran only in CI, or by hand in whichever order I remembered (`tofu fmt`,
`actionlint`, `gitleaks`, the change-detection tests). That means red PRs for problems that take
seconds to catch locally, which matters more now that the app team is a set of agents opening PRs.
Local checks before shared CI are standard shift-left practice, with one rule: they can be skipped
(`git commit --no-verify`), so CI must run the same checks and stay the gate.

## Options considered

1. **No local gate.** Simplest; red PRs and slow feedback.
2. **The `pre-commit` framework.** Standard and rich, but adds a Python dependency and a second
   config format, and its hook environments are yet another thing to pin.
3. **One shared script, a plain git hook, and a CI job that runs the same script** (chosen).
   No extra dependencies; local and CI cannot drift because they run the same code.
4. **`act` as the pre-gate.** Rejected: heavier and less faithful than the real runner, and
   `act` is a debugging helper here, not a gate (see the Preloop comparison in the journal).

## Decision

`scripts/check` runs the fast checks: `tofu fmt -check`, the change-detection tests, `actionlint`
and a `gitleaks` scan. Locally it scans staged changes only; with `--ci` it scans the whole
history and treats a missing tool as a failure rather than a skip. `.githooks/pre-commit` runs it
(enabled once with `git config core.hooksPath .githooks`), and `.github/workflows/check.yml` runs
`scripts/check --ci` on every PR and push to `main`. Container tools are pinned by digest.

## Rationale

One script means one definition of "the checks", used identically by a developer, an agent and
CI. Keeping it to seconds-long checks keeps the hook usable; anything slower belongs in CI.

## Consequences / trade-offs accepted

- The hook is bypassable by design; the `check` job in CI is what enforces it.
- Needs `tofu` and Docker locally. Locally a missing tool is a visible SKIP, so contributors are
  not blocked; CI fails instead.
- Tool image digests must be bumped deliberately.
- Deliberately excluded for now: running each app's own tests, an IaC security scan
  (`trivy config`), and policy checks (Phase 2). They are slower or need design of their own.
