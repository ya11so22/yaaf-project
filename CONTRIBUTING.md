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
  review, merge. Applying to real AWS is a manual, approval-gated dispatch, never automatic.
- **Ownership:** `.github/CODEOWNERS` records who owns what.
- **Limit:** one GitHub identity does everything until Phase 2, so required reviews cannot be
  enforced yet. Until then, ownership is a convention the docs and CODEOWNERS state, not a control
  ([ADR-0008](adr/0008-phase-reslice-cd-and-team-model.md)).

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

## Practices that run across every phase

- **Deliberate failure exercises** — at the end of each phase, break something on purpose (kill
  a pod mid-deploy, revoke a Floci-emulated IAM permission, corrupt a model artifact before
  promotion) and write a one-paragraph postmortem: what broke, blast radius, how it was caught,
  what changed as a result.
- **DORA metrics on the pipeline itself** — instrument GitHub Actions to track deployment
  frequency, lead time for changes, change failure rate, and MTTR for this project's own
  pipeline, starting in Phase 2.
- **Threat model** — a short STRIDE-style pass on the pipeline and infra, done early in Phase 1.
- **One piece of external validation** — by the end, either a small upstream contribution to
  Floci, or a short public write-up of one specific hard problem hit along the way.

## Cost guardrail

AWS Budgets + a billing alarm are set up before anything ever touches real AWS. Real-AWS runs
are milestone validations only (per ADR-0002/0003): spun up briefly, torn down immediately after.

## Definition of done, per phase

Each phase is independently demoable on its own (README + short recording/GIF) — "phase N of 3
(or 4), complete" rather than perpetually unfinished.

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
