# 2026-09-20: A shared local pre-gate

**Phase:** Phase 1 — Commit to running app
**Related ADRs:** [ADR-0009](../../adr/0009-local-pre-gate.md)

## What happened

PR #1 (28 commits) passed all its checks and was merged with a merge commit. Then, asked whether a
per-developer local CI is good practice, concluded yes in a small form and built it in a follow-up
PR: `scripts/check` (fast checks), `.githooks/pre-commit`, and `.github/workflows/check.yml`, which
runs the same script as the source of truth.

- Checks: `tofu fmt -check`, the change-detection tests, `actionlint`, `gitleaks` (staged changes
  locally; full history in CI). The `actionlint` and `gitleaks` images are pinned by digest.
- Locally a missing tool is a visible SKIP; with `--ci` it is a failure, so CI can never pass by
  skipping.
- `.gitattributes` now forces LF on `scripts/check` and `.githooks/*` too: they have no `.sh`
  extension, and a CRLF shebang would break them on Windows checkouts.

## Findings from PR #1 worth keeping

- First real run on GitHub: all 12 images built (1 to 3.5 minutes each), pushed to GHCR, and the
  Trivy results reached code scanning. The Floci smoke test passed in 1m55s: apply from scratch
  (27s), a re-plan with no changes, destroy (60s). The sticky plan comment posted.
- The plan output ends with "You didn't use the -out option to save this plan". Harmless in these
  pipelines (nothing applies from that plan), but at the real-AWS milestone the deploy should save
  the plan, wait for approval, then apply that saved file, so what is approved is what runs. OpenTofu
  can also encrypt plan files.
- `build.yml` compiles, packages and scans; it runs none of the apps' own tests. That, an IaC
  security scan (`trivy config`) and policy checks are the known gaps in "what CI checks".

## act versus Preloop (decision: keep act)

Compared nektos/act with Preloop (a newer local runner that speaks the real GitHub runner
protocol). Preloop claims better fidelity (OIDC, concurrency, job permissions, a debugger) and its
own benchmark reports 79.5% versus act's 74.4% on 39 scenarios. But on this machine it needs WSL2
with nested virtualization, its docs do not cover running Docker inside its job VMs (our jobs
use Docker heavily), and its base image is about 90 GB. `act` already works here and is a
dev-loop helper, not a first-class element. Revisit if native Windows support and Docker-in-VM
land, or if runner-only behaviour becomes costly to debug. Claims about Preloop come from its own
docs; it was not run.

## Verification

- `scripts/check` passes locally in about 7 seconds (11 with `--ci`).
- Each check was proven to fail on a planted fault: a misformatted `.tf` file, a fake GitHub token in
  a staged file, and a workflow with a bad expression. `--ci` with `tofu` removed from `PATH` fails
  instead of skipping. The hook script runs the same checks.
- On the runner (PR #2): `check` passed in 12s. Because that PR touched no app or infra code, it was
  also the first real test of the skip path: `build` and `infra` ran only `changes`, skipped their
  image, `plan` and `smoke` jobs, and both gates still reported pass. This confirms why the gate
  jobs always run rather than the workflows using path filters.

## Next

Merge this PR once green; then branch protection on `main` requiring `build`, `infra` and `check`;
then make the 12 GHCR packages public.
