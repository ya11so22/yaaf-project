# Working rules

The single source of working rules for this repository, for people and agents. Start with `HANDOFF.md` if it exists.

## The owner's standing preferences

- **Zero AWS spend, zero accident risk.** Nothing billable is ever created on real AWS; billable designs are written down
  with a Pricing Calculator estimate. Real AWS only for free-by-construction services (IAM, STS), and only through an
  identity that cannot create anything else (ADR-0020). The owner's AWS account is old (no new Free Tier credits); never
  suggest opening a second account.
- **Simple over complete.** Fewer moving parts, minimal scripts, tools do the real work. Remove what does not earn its
  place.
- **The project is also a course.** Explain the *why* in plain words while working, flag traps with a short
  "Watch out:" line, and write or extend a guide in `docs/guides/` when a concept is new to the project.
- **Honesty about evidence.** Every claim is *designed*, *verified on Floci* or *verified on real AWS*. Retract claims
  that turn out wrong. Prove a new check against a planted fault before trusting it.
- No job-search timeline steering; the project's own quality sets the order of work.

## Branching and merging (GitHub Flow)

- `main` is always deployable: Argo CD deploys from it. It is protected: PRs only, required checks `check`, `build`,
  `infra`, no force pushes.
- Every change is one short-lived branch from `main`, named `<type>/<slug>` with `type` one of `feat`, `fix`, `docs`,
  `chore`, `infra`, `ci`, `app` (app-team changes under `app/src`), `drill` (deliberate failure exercises).
- Open a PR early; **squash-merge**; the branch is deleted on merge. Commit and PR titles are short and imperative.
- `bot/bump-images` is the only long-running branch: the pins bot reuses it for its one open PR, which auto-merges.
- Old history lives at tags (`archive/windows-era`), not in old branches. Delete merged branches.

## Working model (simulated team)

- **App team:** Claude agents changing `app/src` only, through PRs, from GitHub Issues labelled `ready-for-agent`.
- **Platform engineer:** the owner, code owner of everything else (`.github/CODEOWNERS`). One GitHub identity does both,
  so required reviews cannot be enforced; ownership is a convention.
- **Issues** live in GitHub Issues (`ya11so22/yaaf-project`), via `gh`. Labels: `needs-triage`, `needs-info`,
  `ready-for-agent`, `ready-for-human`, `wontfix`. External PRs are not a request surface.

## Checks

`scripts/check` runs the fast checks (fmt, script tests, manifest schemas, zizmor, actionlint, gitleaks). Enable the hook
once with `git config core.hooksPath .githooks`. CI runs the same script as the required `check`; the hook is a
convenience, CI is the gate (ADR-0009). New workflows follow ADR-0024 and `docs/guides/ci-cd-pipeline-standard.md`.

## Documentation practice

Every decision, step and milestone is documented well enough to explain later. Do it as part of finishing the work,
unprompted.

- **Decisions** go in `adr/`, written *before* implementing (template `adr/0000-template.md`, next number after the
  highest ever used, including the archived 0001 to 0019). Read the ADRs that touch an area before changing it; if a
  change contradicts one, say so and amend or supersede it rather than silently overriding.
- **Domain terms** live in `CONTEXT.md` (single context; `app/` is vendored upstream code, not part of it). Use its terms.
- **Steps**: one short journal entry per session that changed something, `docs/journal/YYYY-MM-DD-<slug>.md` from
  `docs/journal/_template.md`: what happened, why (or the ADR), how it was verified, what to learn, what is next.
- **Milestones**: tick `docs/milestones.md` as work lands.
- **Failure exercises** are scenarios in `docs/scenarios/` (ADR-0028): write the spec first, run it, and write the report
  in `docs/postmortems/`.
- **Guides**: `docs/guides/` from `docs/guides/_template.md`, indexed in `docs/guides/README.md`.
