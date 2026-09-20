# 2026-09-21: CI redesign — GHCR for images, Floci only for infra validation

**Phase:** Phase 1 — AWS IaC + GitHub Actions foundation
**Related ADRs:** [ADR-0007](../../adr/0007-ci-split-ghcr-and-floci-scope.md), amends [ADR-0002](../../adr/0002-aws-emulation-strategy.md)

## What happened

Questioned the first `build.yml` (a fresh Floci and `tofu apply` in every per-service job, with
the registry destroyed at the end of each run), worked the design through as a grill-me
interview (19 questions), and rebuilt CI on the branch. Decisions, all in ADR-0007: two
pipelines; images on GHCR; Floci only for infra validation; change detection stays a script
(diffing from the merge-base); one always-running required check per pipeline; the repository
goes public with the history's email rewritten first. Team framing: the "app team" is a handful
of Claude agents opening PRs, the project owner is the DevOps engineer owning infra/pipelines.

Written this session (all on the branch, nothing pushed to GitHub's settings):

- `build.yml`: change detection, per-service matrix, amd64 build with Actions cache, Trivy
  report-only, push of `:<sha>` to GHCR, `build` gate. `packages: write` only on the image job.
- `infra.yml`: `fmt`/`validate`/`plan` (no Floci), sticky PR comment, Floci smoke test
  (apply, no-diff re-plan, destroy), `infra` gate.
- `cleanup.yml`, `.github/CODEOWNERS`, `.claude/settings.local.json` in the repo `.gitignore`.
- Third-party actions pinned to SHAs; `trivy-action` v0.36.0 is past the patched version of
  advisory GHSA-9p44-j4g5-cfx5.

## Verification

- `tofu plan` works with no Floci (fresh state, dead endpoint): 53 resources, which is what
  makes the no-Floci plan job possible.
- `changed-services.test.sh`: 10 scenarios pass. It found a real bug in the script: `[ -n ... ] &&
  echo` returned failure when the last service folder had no Dockerfile, which under `set -e`
  produced an empty result (every build silently skipped). Fixed and covered by a test.
- Caught before it could fail on a runner: Git on Windows had recorded both scripts as mode
  `100644`, so running them directly would have been "Permission denied". Set to `100755`.
- `actionlint` (with shellcheck) is clean on all three workflows; `tofu fmt -check` is clean.
- The plan-comment script was run against a fake GitHub client: creates a comment when none
  exists, updates the sticky one and ignores unrelated comments, truncates a 100k-char plan.
- Not verified until the first run on GitHub: Floci start via compose on a runner, the full
  smoke test (apply/re-plan/destroy of all four modules), the heavy builds (`adservice`,
  `cartservice`), Trivy and SARIF upload, GHCR push, and the cleanup package-name format.

## Next

Agreed sequence, pausing for explicit approval before the hard-to-reverse steps: rewrite the 20
commits carrying the Gmail address to the GitHub noreply address and force-push; make the
repository public and apply the Actions settings; open the PR into `main` (first real runs);
protect `main`; make the GHCR packages public.
