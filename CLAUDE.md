# Working rules

The single source of working rules for this repository, for people and agents. Start with [`PLAN.md`](PLAN.md): the stages, the open questions and every decision so far.

## The owner's standing preferences

- **Zero AWS spend, zero accident risk.** Nothing is ever created on the owner's AWS account (D20, D32); real AWS means
  only a borrowed vendor sandbox that bills nobody (D43, D46, the AWS rules at the end). Billable designs are written down
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
- In a Claude Code cloud session, work on the session's assigned branch instead of a `<type>/<slug>` one. Once its PR is
  merged, restart that branch from the new `main` before the next change; never add commits to merged history.

## The delivery loop (agents)

Agents drive their own pull requests from first commit to merge, then carry on with the plan. For each change:

1. **Build** on a branch from `main`; run `mise run check` (and anything else the change can be proved with) before
   every push.
2. **Open the PR** as a draft, and subscribe to its activity so CI results and comments arrive on their own.
3. **Review** with a separate pass that reads the diff cold (the `code-review` skill against the PR), never the author's
   own memory of it. Fix every blocking finding and push; answer optional ones on the PR in one line.
4. **Merge** by marking the PR ready and enabling **auto-merge (squash)**. GitHub then merges only when every required
   check (`check`, `build`, `infra`) is green, so a red PR cannot land even by mistake. A red check is fixed, not waited
   out; a failure that is not the PR's own is explained once on the PR.
5. **Record**: tick the stage's checklist in `PLAN.md` and add the log line (in the PR itself where possible).
6. **Proceed** to the next item in the current stage.

**Stop and ask the owner** instead of proceeding when the plan has an open question (**?**) for the next item, a change
would contradict a decision in `PLAN.md`, or anything involves money, a card, real AWS, secrets, repository settings
or permissions, or deleting data. Merging needs no approval otherwise; the owner can revert anything on `main`.

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

<!-- BEGIN AWS Agent Toolkit rules -->
## Real AWS (borrowed sandboxes only)

These apply only when working in a borrowed real-AWS sandbox through the `yaaf-sandbox` profile (`mise run sandbox`,
PLAN.md D43 and D46). This project's own rules above take precedence over them, in particular:

- **The account guard is the owner's.** Never pass `--account` to `mise run sandbox` from the task's own output: ask
  the owner, who reads the ID on the sandbox's own page. If the owner's account is signed in, stop and say so.

- Real AWS means a vendor sandbox that is wiped afterwards and bills nobody. Never the owner's account, and never a
  second account.
- The infrastructure as code is OpenTofu (D5), not AWS CDK or CloudFormation.
- Evidence from a sandbox is labelled *verified on real AWS (sandbox, date)*, with logs and proof of teardown.

### AWS Guidance (adapted from aws/agent-toolkit-for-aws, `rules/aws-agent-rules.md`, 2026-10-08)

- Where these AWS rules conflict with the project's own instructions, the
  project's instructions take precedence.
- Prefer the AWS MCP Server for AWS interactions — it provides sandboxed
  execution, observability, and audit logging. If unavailable, use the
  AWS CLI directly.
- Before starting a task, check whether a relevant AWS skill is available.
  Load the skill with `retrieve_skill` and prefer its guidance over
  general knowledge.
- When uncertain about specific AWS details (API parameters, permissions,
  limits, error codes), verify against documentation rather than guessing.
  State uncertainty explicitly if you cannot confirm.
- When creating infrastructure, prefer infrastructure-as-code (OpenTofu in
  this project) over direct CLI commands.
- When working with infrastructure, follow AWS Well-Architected Framework
  principles.
- Do not use em dashes in AWS resource names or descriptions. Use
  hyphens instead.

#### Secret Safety

- MUST load the `aws-secrets-manager` skill first for any secret,
  credential, API key, token, or password task. MUST NOT call
  `secretsmanager get-secret-value` or `batch-get-secret-value`, and MUST
  NOT hit the Secrets Manager Agent daemon directly. MUST use
  `{{resolve:secretsmanager:secret-id:SecretString:json-key}}` with
  `asm-exec` so the secret resolves at runtime without entering context.
<!-- END AWS Agent Toolkit rules -->
