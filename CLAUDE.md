# Working rules

The single source of working rules for this repository, for people and agents. Start with [`PLAN.md`](PLAN.md): the stages, the open questions and every decision so far.

## The owner's standing preferences

- **Zero AWS spend, zero accident risk.** Nothing is created on real AWS (D20, D32); billable designs are written down
  with a Pricing Calculator estimate. The owner's AWS account is old (no new Free Tier credits); never suggest opening a
  second account. Free tiers elsewhere (GitHub Actions for a public repository, Vercel Hobby, Cloudflare quick tunnels)
  are fine; anything that needs a card on file is asked about first.
- **Plan in chat.** Before a stage or any non-trivial change, ask the owner questions until the goal is shared; record
  the answers in `PLAN.md` (below). No ADRs.
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

- **App teams:** Claude agents changing `app/src` only, through PRs, from GitHub Issues labelled `ready-for-agent`. Stage 3
  of the plan splits them into two teams (Checkout, Catalog) in their own repository (D35).
- **Platform engineer:** the owner, code owner of everything else (`.github/CODEOWNERS`). One GitHub identity does both,
  so required reviews cannot be enforced; ownership is a convention.
- **Issues** live in GitHub Issues (`ya11so22/yaaf-project`), via `gh`. Labels: `needs-triage`, `needs-info`,
  `ready-for-agent`, `ready-for-human`, `wontfix`. External PRs are not a request surface.

## Checks

`scripts/check` runs the fast checks (fmt, script tests, manifest schemas, zizmor, actionlint, gitleaks). Enable the hook
once with `git config core.hooksPath .githooks`. CI runs the same script as the required `check`; the hook is a
convenience, CI is the gate (D9). New workflows follow D24 and `docs/guides/ci-cd-pipeline-standard.md`.

## Documentation practice

Everything is documented well enough to explain later, as part of finishing the work, unprompted.

- **`PLAN.md` is the one living document**: the architecture, the stages with their checklists and open questions, the
  decisions and the log. A decision is one row: *what* and *why*, numbered after the highest ever used (never reuse a
  number). If a change contradicts a decision, say so in chat and change the row; do not silently override it. Tick the
  stage's checklist as work lands and add one log line per merged PR. Code comments cite decisions as `PLAN.md D<n>`.
- **Domain terms** live in `CONTEXT.md` (single context; `app/` is vendored upstream code, not part of it). Use its terms.
- **Failure exercises** are scenarios in `docs/scenarios/` (D28): write the spec first, run it, and write the report
  in `docs/postmortems/`.
- **Guides**: `docs/guides/` from `docs/guides/_template.md`, indexed in `docs/guides/README.md`.
- **Research** that informs a stage goes in `docs/research/`, dated; it is a record and is not rewritten later.
