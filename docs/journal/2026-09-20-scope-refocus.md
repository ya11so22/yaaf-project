# 2026-09-20: Scope refocus — phases that end in a running app

**Phase:** Phase 1 (re-scoped)
**Related ADRs:** [ADR-0008](../../adr/0008-phase-reslice-cd-and-team-model.md), builds on [ADR-0007](../../adr/0007-ci-split-ghcr-and-floci-scope.md)

## What happened

Reviewed the project against the original brief and against what live infrastructure looks like.
The infrastructure modules and CI pipelines were largely done, but the review found that nothing
deployed the built images (the local cluster held only system namespaces), the two environments
were unnamed and unconnected, and the team model existed only in conversation.

Decisions, all in ADR-0008 (five decision questions plus two on CD, all adopted as recommended):

- Re-slice the phases so each ends with a running app. Minimal CD moves into Phase 1.
- Name the environments `dev` (Floci) and `milestone` (real AWS); promote one image digest
  between them; no production.
- CD in Phase 1 is push-based from Actions: a throwaway Floci in the runner for dev (GitHub's
  runners cannot reach the local cluster), and a manual, approval-gated OIDC deploy for
  milestone. Argo CD (GitOps) moves to Phase 2, where per-PR environments need it. Manifests are
  deployed with kustomize.
- Minimal observability and the team access model (bot identity, namespace RBAC) go in Phase 2.
- The team is simulated: Claude agents are the app team, the project owner is the DevOps engineer.
  Documented as such, including the limit that one GitHub identity cannot enforce reviews yet.
- `act` and the VS Code extension stay a development-loop helper, not a first-class element.

Docs updated: the root README (scope, team model, phases, status), `CONTRIBUTING.md` (working
model in place of "solo"), `docs/milestones.md` (re-sliced), `CONTEXT.md` (terms), the `infra`,
`platform`, `pipelines`, `policy` and `aws-milestone` READMEs, and a new
[`docs/live-infra-gap-analysis.md`](../live-infra-gap-analysis.md) scorecard.

## Corrections made along the way

- The IAM module had been applied (12 entries in state), but the milestone said it was pending.
- ADR-0007 and its journal entry were dated 2026-09-21; the system date is 2026-09-20. Fixed, and
  the journal file renamed.

## Verification

Documentation only. Relative links in every changed Markdown file were checked to resolve to
existing files.

## Next

Agreed sequence, pausing for explicit approval before the hard-to-reverse steps: rewrite the 20
commits carrying the Gmail address to the GitHub noreply address and force-push; make the
repository public and apply the Actions settings; open the PR into `main` for the first real
runs; protect `main`; make the GHCR packages public. Then the Phase 1 CD work.
