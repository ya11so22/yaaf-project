# Working conventions

This is a portfolio project that behaves like a small team on purpose: the point is to practice
real conventions, not to move fast and skip them. The team is simulated: a handful of Claude
agents are the app team, and I am the DevOps engineer who owns the platform.

## Working model

| Role | Who | Owns | Changes |
|---|---|---|---|
| App team | Claude agents | `app/src/**` | Open PRs; the pipeline builds, scans and pushes images |
| Platform (DevOps) | Project owner | Everything else: `infra/`, `.github/`, `deploy/`, `adr/`, `policy/`, `platform/`, `pipelines/` | Open PRs; the plan comment and smoke test run, then review |

- **Intake:** GitHub Issues. `ready-for-agent` marks work an app-team agent can pick up without
  further specification; `ready-for-human` is platform work. Labels are defined in
  `docs/agents/triage-labels.md`.
- **App change:** branch, PR touching `app/src` only, green `build` check, merge. Agents do not edit
  workflows, infrastructure or policy.
- **Infra or pipeline change:** branch, PR, plan comment on the PR, green `infra` check, code-owner
  review, merge. Nothing is applied to real AWS from CI (ADR-0020); the local AWS is applied by `scripts/dev-up.ps1`.
- **Ownership:** `.github/CODEOWNERS` records who owns what.
- **Limit:** one GitHub identity does everything, so required reviews cannot be enforced. Ownership is a
  convention the docs and CODEOWNERS state, not a control ([ADR-0021](adr/0021-project-purpose-scenario-and-scope.md)).

## Local checks (pre-gate)

`scripts/check` runs the fast checks in a few seconds: `tofu fmt -check`, the change-detection
tests, `actionlint`, and a `gitleaks` scan of staged changes. It needs `tofu` and Docker; a missing
tool shows as a visible SKIP locally.

- Enable the hook once: `git config core.hooksPath .githooks`. Or run `scripts/check` by hand.
- It can be skipped (`git commit --no-verify`), so it is a convenience, not a control. The `check`
  workflow runs `scripts/check --ci` (full-history secret scan, missing tools fail) on every PR and
  is the real gate ([ADR-0009](adr/0009-local-pre-gate.md)).

## ADRs first

Every nontrivial choice gets a short ADR (`/adr`, using `0000-template.md`) written *before*
asking Claude Code to implement it, not after. This is the main defense against "can't explain
why the infra code is shaped this way" under questioning.

## Documentation practice

Decisions, steps, and milestones all get documented as they happen, not reconstructed later —
see `CLAUDE.md`'s "Documentation practice" section for the standing convention Claude Code
follows every session:

- Decisions → `/adr` (as above)
- Steps → `docs/journal/`, one dated file per session/step
- Milestones → `docs/milestones.md`, checked off as phases progress
- Deliberate failure exercises → `docs/postmortems/`
- How things work, and what to watch out for → `docs/guides/`

## Practices that run across every phase

- **Deliberate failure exercises** — at the end of each phase, break something on purpose (kill
  a pod mid-deploy, revoke a Floci-emulated IAM permission, corrupt a model artifact before
  promotion) and write a one-paragraph postmortem: what broke, blast radius, how it was caught,
  what changed as a result.
- **Threat model** — a short STRIDE-style pass on the pipeline and infra, done early in Phase 1.
- **One piece of external validation** — by the end, either a small upstream contribution to
  Floci, or a short public write-up of one specific hard problem hit along the way.

## Cost guardrail

No billable resource is ever created on real AWS. Anything that would bill runs on Floci or is designed
with a Pricing Calculator estimate. Real AWS is used only for free-by-construction services (IAM, STS),
through an identity that cannot create anything else (proposed in ADR-0020; see
`docs/guides/aws-cost-safety.md`). A zero-spend budget is a tripwire, not a brake: AWS has no hard cap.

## Definition of done, per phase

Each phase is independently demoable on its own (README + short recording/GIF) — "phase N of 3,
complete" rather than perpetually unfinished.

## Claude Code workflow

This repo vendors Matt Pocock's engineering/productivity skills under `.claude/skills` (see
README attribution). Useful entry points for this project:

- `/grill-with-docs` or `/grill-me` to think through a phase or ADR before writing it down.
- `/to-spec` / `/to-tickets` to turn an ADR or phase plan into scoped, implementable slices.
- `/implement` / `/tdd` to build a slice with red-green-refactor discipline.
- `/code-review` before merging.
- `/ask-matt` if unsure which skill fits.

Run `/setup-matt-pocock-skills` once to configure issue-tracker preference (this project uses
GitHub Issues) and triage labels.
