# Plan

The one living document for this project: what it is for, how it is built and run, the stages of work, the questions still
open, and the decisions made so far. It replaces the ADRs, the handoff, the milestones and the journal (retired on
2026-10-08; readable in git at commit `c4c44b0`, for example `git show c4c44b0:adr/0024-ci-cd-pipeline-standard.md`).

**How it is used.** Each stage starts with questions in the chat session; the answers become decisions below (one line
of *what* and one of *why*), the stage's checklist is ticked as pull requests land, and each merged PR adds one line to
the log. Code comments cite decisions as `PLAN.md D<n>`. Decision numbers are stable and never reused. D5, D6, D9 and D20 to D29 keep the
numbers they had as ADRs; citations of the archived ADR-0011 and 0013 now point to D23, 0012 and 0014 to D22, and
0018 and 0019 to D21, the decisions that absorbed them. Numbers 1 to 19 that are not listed have no row here.

## What this is

A portfolio and learning project for a DevOps engineer moving towards platform and Solutions Architect roles. A
**fictional mid-size retailer that takes card payments** moves its storefront (Google's Online Boutique, vendored in
`app/`) to AWS. The AWS is **Floci**, a free local emulator: nothing billable is ever created on real AWS.

The project simulates the two kinds of pressure a real platform lives under, and answers each from a different role:

| Client | Pressure | Role that answers | Evidence it produces |
|---|---|---|---|
| **1. Developer teams** | Constant pull requests, much of it AI-written, that must be good and relevant before it ships | **DevOps / platform** | Gates that catch bad change, each proved against a planted fault; delivery metrics (DORA) |
| **2. Shop users** | Traffic spikes, abuse, failing dependencies, disasters | **SRE** operates it; the **solutions architect** decides what it must withstand and at what cost | SLOs, burn-rate alerts, scenario reports with measured recovery; designs with cost and DR tiers |

The SA side owns the targets ("checkout survives losing a zone, recovered in 15 minutes, at $X a month"); the SRE
scenarios produce the evidence that a design holds. Each claim carries an **evidence label**: *designed*, *verified on
Floci*, or *verified on real AWS*.

## The architecture

| Piece | What | Serves |
|---|---|---|
| **Workbench** | Claude Code cloud sessions: design, code, pull requests. A SessionStart hook installs the locked tools; `up` starts Docker. No long-lived machine | Development |
| **App repo** *(stage 3)* | The shop's source, its image builds and tests, the gates for agent PRs. Two teams by domain: **Checkout** (checkout, payment, cart, shipping, currency, email) and **Catalog** (frontend, product catalog, recommendation, ads) | Client 1 |
| **Platform repo** (this one) | OpenTofu, Argo CD Applications, image pins, scenarios, the architecture track, this plan | Both |
| **Ephemeral environment** *(stage 2)* | The full stack (Floci, three OpenTofu roots, EKS on k3s, Argo CD, the shop) built from git on a GitHub arm64 runner. One workflow, three uses: a **per-PR deploy check**, **continuous verification** after each merge, and an **on-demand live demo** | Both |
| **Live demo** *(stage 4)* | The ephemeral environment held open for up to 6 hours and published through a named Cloudflare tunnel: `shop.yaafsome.fyi` open to all, `argocd.` and `grafana.yaafsome.fyi` behind a Cloudflare Access login | Presenting |
| **Observability** *(stage 5)* | Prometheus and Grafana in the environment: SLOs, burn-rate alerts, the dashboard worth presenting | Both |
| **Showcase** *(stage 7)* | An always-on static site on Vercel at `yaafsome.fyi`: the story, the decisions, scenario reports, metric snapshots, the live-demo link | Presenting |
| **Production** | *Designed* for real AWS in the architecture track, never built. The ephemeral environment is the evidence that the design builds and runs | SA |

Watch out: there is no long-lived environment, so GitOps never "keeps a cluster in step for weeks" here. It proves itself
by converging a fresh cluster from git on every run; say exactly that when presenting.

## Stages

Each stage is one or a few pull requests. Questions marked **?** are asked at the start of the stage.

### Stage 0: reset the plan *(this PR)*

- [x] The two clients, the architecture and the stages agreed in chat (2026-10-08)
- [x] ADRs, handoff, milestones and journal folded into this file; citations in code point here

### Stage 1: the cloud workbench

- [x] SessionStart hook: installs mise (pinned) and `mise install --locked`, enables the git hook (6 s from a clean
      state); `up` starts Docker
- [x] `mise.toml` and the tasks lose Colima; tasks are `up`, `down` and `check`
- [x] Nothing persists (D39): Floci in memory only; `up` rebuilds anything stale; the k3s repair and `reset` removed
- [x] Removed (D40): the EC2 workstation, the S3 + CloudFront portal, floci-dash, Headlamp. The IAM drill stays a script
      and becomes a stage 6 scenario
- [x] Proved in a session (D44): the AWS layer from nothing in 201 s; re-run in place with no changes in 33 s; after a
      simulated worker restart (Floci killed), removed and rebuilt from nothing in 111 s. The cluster layer cannot run
      in a session (cgroup v1), so it is proved on the arm64 runner in stage 2
- [x] CI's extra "converge" apply removed: with CloudFront gone, a second apply shows no changes

### Stage 2: the ephemeral environment

- [x] One workflow on `ubuntu-24.04-arm` (`environment.yml`): Floci, the three roots, Argo CD at the commit under test,
      every Application `Synced` and `Healthy` and the shop and Argo CD answering (`up --strict`), torn down. First run
      2026-10-08: all five Applications healthy, the shop answering, **207 s from nothing**
- [x] Rebuilds on pull requests that touch what it builds, and after every merge to `main` (continuous verification)
- [x] An always-running `environment` gate job (D24): it reports on every PR, rebuilding only when the PR touches what it
      builds; path detection is one tested script for both gated workflows (`changed-paths.sh`, renames and a missing base
      count as a change)
- [ ] Owner: add `environment` to main's required checks (Settings, Branches)
- [x] The build time is written to the job summary on every run: the platform's measured recovery time
- [x] Proved against a planted fault: adservice pinned to a digest that does not exist; `online-boutique-dev` stayed
      `Progressing`, the pod in `ImagePullBackOff`, the job failed with the diagnostics, and teardown still ran
- [x] The runner is asserted to have cgroup v2 and 8 GB of free disk before the build starts
- [ ] Floci's IAM enforcement on (`FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`), and nothing authenticates with the `test` key
      that bypasses it
- [x] OpenTofu's S3 lock proved on Floci (`scripts/drills/state-lock.sh`, 2026-10-08): while one `plan` holds the lock
      a second is refused with "Error acquiring the state lock"; the control, the same race with the lock off, is not
      refused. Plans, not applies: both take the same lock, and a plan changes nothing
- [ ] Claims labelled honestly: the ALB carries traffic on Floci (the shop worked through it on 2026-10-05) but its
      health checks do nothing; Floci's ElastiCache is Valkey

### Stage 2b: durable data (D42)

The platform is rebuilt from git; the data is not, and must survive any rebuild.

- [ ] RDS PostgreSQL (orders) and ElastiCache (carts) created by the foundation root; the cart service points at
      ElastiCache instead of the in-cluster `redis-cart`
- [ ] Orders are stored: a change to `checkoutservice` (the Checkout team's first task once stage 3 exists, or done
      here). No card numbers, only an opaque payment reference; a check that rejects anything shaped like a card number
      in seed data and backups
- [ ] Backups: `pg_dump` and the cache's snapshot, `age`-encrypted, pushed to GHCR as OCI artifacts; one taken before
      every teardown; the key in a GitHub secret plus the owner's offline copy
- [ ] Restore on `up` from the latest backup, and the drill: a timestamped canary row written before the "disaster", the
      platform rebuilt, the data restored; RTO and RPO measured from it; a planted corrupt backup must fail loudly
- **?** The RPO targets for orders and for carts (set in the architecture track's requirements)
### Stage 3: split the repositories and the teams

- [ ] A new app repository holds `app/`, the image builds, the scan and the attestations; this repository keeps the pins
- [ ] Cross-repository pin bumps: an app-repo release opens the pin PR here (the GitHub App bot)
- [ ] Two teams with their own CODEOWNERS entries and issue labels
- **?** The app repository's name, and whether the pin bump is pushed from the app repo or pulled from here

### Stage 4: the live demo

- [x] The domain `yaafsome.fyi`, registered on Cloudflare (2026-10-08)
- [ ] The edge proved end to end: the owner does the one-time dashboard setup
      ([guide](docs/guides/cloudflare-tunnel-and-access.md)), then `edge-check` passes (a test page through the tunnel at
      `check.yaafsome.fyi`; Access in front of `argocd.` and `grafana.`, not `shop.`)
- [ ] `workflow_dispatch` runs the stage 2 workflow and holds it open; `cloudflared` publishes the shop and Argo CD
- [ ] A read-only Argo CD account, even behind Access; the admin login is never reachable through the tunnel
- [ ] The URLs appear on the repo's Deployments panel (environment `demo`); cancelling the run tears it down
- [ ] Demos are attended and time-boxed (D45): started when presenting, never looped to look always-on; a recorded
      walkthrough on the showcase for everyone else
- [ ] Threat model entry for what the tunnel and its token expose
- **?** Keep the Host-header rewrite in the dashboard, or add the public hostnames to the `HTTPRoute`s

### Stage 5: observability

- [ ] Prometheus and Grafana by Argo CD; SLOs for browsing and checkout; multiwindow, multi-burn-rate alerts
- [ ] The upstream load generator as the steady traffic source
- [ ] An alert proved against a planted fault under load

### Stage 6: client 2 scenarios

Each is specified before it is run (`docs/scenarios/<name>/spec.md` and `inject.sh`) and reported after
(`docs/postmortems/`, D28).

- [ ] A traffic spike absorbed by a HorizontalPodAutoscaler, measured against the SLO
- [ ] A failing dependency (redis-cart down) seen as SLO burn, then an incident and a postmortem
- [ ] Abuse: bot traffic and rate limiting at the Gateway, framed against PCI DSS
- [ ] Disaster recovery: the stage 2b drill as a scenario: rebuild from nothing (RTO), restore orders and carts from the
      latest backup (RPO), with the canary as the measure
- [ ] Platform scenarios carried over: configuration drift reverted by self-heal, stuck or lost OpenTofu state, a leaked
      credential, an action tag rewritten in the supply chain, overbroad OIDC trust, a mislabelled image

### Stage 7: the showcase

- [ ] A static site on Vercel at `yaafsome.fyi`, built from this repository, a preview per pull request, a link to the live demo
- **?** Generated from the Markdown here, or a small hand-written site

### Stage 8: client 1 at scale

- [ ] Gates for agent PRs, each proved against a planted fault: scope (by repository permission after stage 3), a
      dependency existence and lockfile check, a size limit, SAST as a ratchet on new high findings
- [ ] Claude Routines as the two teams, working issues labelled `ready-for-agent`
- [ ] DORA metrics from GitHub data, shown in the showcase
- [ ] Canary rollouts with automated analysis (Argo Rollouts and Prometheus) as the last line against a bad change

### Real-AWS evidence, borrowed (D43)

Real AWS without ever touching the owner's account: vendor sandbox accounts that are wiped afterwards and bill nobody.

- [x] Prepared (*designed*): `mise run sandbox` signs in with `aws login --remote` and stops at two guards (the owner's
      account refused if `YAAF_OWNER_ACCOUNT_ID` is set; the sandbox's ID given by the owner), then sets up the AWS
      Agent Toolkit. The guards are proved against a fake `aws` with a planted fault; the toolkit commands themselves
      run for the first time in the spike below ([guide](docs/guides/real-aws-sandbox.md))
- [ ] Owner: set `YAAF_OWNER_ACCOUNT_ID` (your own account's ID) in the cloud environment's settings
- [ ] A spike in the free AWS Builder Center sandbox (8 hours, once a week, from selected workshops): can we get CLI
      credentials, create an IAM OIDC provider, an EKS cluster and an RDS instance? Recorded either way
- [ ] If it can: one run of the foundation root against real AWS, recorded as *verified on real AWS (sandbox, date)*
      with logs and proof of teardown
- **?** If the free sandbox falls short, whether to pay for a sandbox subscription (KodeKloud, Pluralsight: a card, but
      never on AWS)

### The architecture track (runs alongside, in `docs/architecture/`)

- [x] Scenario chosen: a card-payments retailer, PCI DSS as the control frame (2026-09-24)
- [ ] Requirements and constraints, then architecture views as diagrams in code
- [ ] Well-Architected review v1 with a findings register
- [ ] Reliability and DR tiers with a cost per tier; a cost model with real pricing
- [ ] Designs only: Karpenter, Spot and Graviton fleets, multi-AZ and multi-Region recovery, tail sampling
- [ ] Migration options (the 7 Rs); security and compliance (the threat model, a PCI DSS mapping); AI architecture;
      governance (multi-account, on paper)
- [ ] Review v2 after stage 6; customer-facing material; an interview kit

### Backlog

- The shopping-assistant replatform from Google Cloud (Bedrock designed, PostgreSQL with pgvector built on Floci)
- The Floci CloudFront tag fix (`docs/research/patches/`): finish the end-to-end proof, then ask before opening it
  upstream (no `Co-Authored-By` trailers for AI tools there). Nothing in the project uses CloudFront since D40, so this is only an
  upstream contribution now
- Filing the other upstream findings (`docs/research/2026-09-24-floci-upstream-findings.md`)
- Revisit D20 (an IAM-only lane on the owner's account) once the project is complete; nothing found in 2026 changes it
- Oracle Cloud always-on is closed: its Always Free Arm allowance was halved on 2026-06-15, and it needs a card
- Owner, in the AWS console, whenever convenient: nothing running in any Region, root MFA on, no root keys, a zero-spend
  budget ([guide](docs/guides/aws-cost-safety.md))

## Decisions

| | Decision | Why |
|---|---|---|
| <a id="d5"></a>D5 | OpenTofu, not Terraform | The community-governed fork; same language and providers |
| <a id="d6"></a>D6 | GitHub Actions reaches AWS through OIDC: `ecr-push`, `tofu-plan`, `tofu-apply`, each trusted on an exact `sub` and `aud` | No stored keys; a role can be assumed only from the workflow and branch it was made for |
| <a id="d9"></a>D9 | One script, `scripts/check`, is the fast gate for the git hook and for CI | One definition of "the checks"; the hook is a convenience, CI is the gate |
| <a id="d20"></a>D20 | *Rejected 2026-10-03:* a zero-spend lane on real AWS for IAM and STS | The local proofs were enough; anything real waits until the project is complete |
| <a id="d21"></a>D21 | The engagement: a card-payments retailer moves to AWS; Online Boutique vendored at `72ba613`; PCI DSS as a mapping, never a claim; every claim carries an evidence label | A realistic story an architect would run, without pretending to production |
| <a id="d22"></a>D22 | Floci is the AWS; three OpenTofu roots (`bootstrap` with local state, `foundation` and `cluster` with state in S3 on Floci and native locking); EKS is Floci's k3s pinned to the Kubernetes minor in `mise.toml`; everything published on loopback | Real AWS APIs at no cost; roots split by lifecycle the way teams layer infrastructure; Floci holds the Docker socket, so it must never be reachable from a network |
| <a id="d23"></a>D23 | GitOps: Argo CD reconciles from git every 60 s; pins live in git and are bumped by a GitHub App bot PR with auto-merge; rollback is reverting the source, not the pin | Nothing pushes into the cluster; the bot recomputes pins from source, so a pin-only revert is undone within a minute (the Phase 1 failure exercise) |
| <a id="d24"></a>D24 | The pipeline standard: `permissions: {}`, actions pinned by SHA, no `pull_request_target` or `workflow_run`, zizmor; PRs never push images; `main` pushes by digest with SLSA provenance and a CycloneDX SBOM; pins by digest; Trivy fails on new fixable criticals (expiring ignores); a weekly rescan; Scorecard; Dependabot with a cooldown; one always-running gate job per required workflow | Researched against GitHub, OpenSSF, SLSA and DORA guidance; each gate proved against a planted fault ([guide](docs/guides/ci-cd-pipeline-standard.md)) |
| <a id="d25"></a>D25 | One `mise.toml` and a committed `mise.lock` pin every tool and the shared values; CI installs from the lockfile; the AWS CLI and kubectl read `.aws/` and `.kube/` in the repository | A version written once cannot disagree with itself; project commands can never pick up real AWS credentials. Watch out: `awscli` has no checksum in the lock (AWS publishes none) |
| <a id="d26"></a>D26 | Argo CD app-of-apps: OpenTofu installs Argo CD, one `AppProject` (`dev`) and one root Application; every other Application is a file in `deploy/apps/`; sync waves order them | Platform changes arrive by pull request, with least privilege on what may be deployed from where |
| <a id="d27"></a>D27 | Images are arm64 only, built on `ubuntu-24.04-arm`, with an architecture check on the files inside and `-arm64` content tags | Native builds; a mislabelled image cannot ship. Stays arm64: the ephemeral environment runs on arm runners too (D31) |
| <a id="d28"></a>D28 | Failure exercises are scenarios: `docs/scenarios/<name>/` with a spec written first and an inject script; each run reported in `docs/postmortems/` | Spec first keeps them honest; a wrong hypothesis is retracted in the report, not edited away |
| <a id="d29"></a>D29 | Gateway API instead of Ingress: Traefik's Gateway, one `HTTPRoute` per hostname in its service's namespace; CRDs from Traefik's chart | The platform owns the Gateway and teams own their routes, the split the API is designed for ([guide](docs/guides/gateway-api.md)) |
| <a id="d30"></a>D30 | Work happens in Claude Code cloud sessions; the Mac and Colima are retired | No single machine to keep alive; anyone can reproduce the project from the public repository |
| <a id="d31"></a>D31 | Environments are ephemeral, built on GitHub arm64 runners: per-PR check, continuous verification, on-demand demo | Free for a public repository, native arm64, 4 vCPU and 16 GB; the demo is the same thing that gates every merge |
| <a id="d32"></a>D32 | Production is *designed* for real AWS and never built; continuous verification is the evidence | Zero spend and zero accident risk, stated honestly instead of faking a long-lived production |
| <a id="d33"></a>D33 | The live demo goes out through a **named** Cloudflare tunnel (`yaaf-demo`) on `yaafsome.fyi`: the shop public, Argo CD and Grafana behind Cloudflare Access (email one-time code). *Amended 2026-10-08:* first a quick tunnel (`*.trycloudflare.com`), replaced once the owner registered the domain | Stable URLs to present, and a login in front of the operator UIs, which a quick tunnel cannot have. Watch out: the tunnel token lets anyone attach to these hostnames; it lives only in the `demo` environment secret |
| <a id="d34"></a>D34 | Live UIs are the shop, Argo CD and (stage 5) Grafana; everything else is removed (D40) | They tell the platform and reliability story; the rest duplicated it or only made sense on a laptop |
| <a id="d35"></a>D35 | The app moves to its own repository, worked by two agent teams split by domain (Checkout, Catalog) | Least privilege by repository permission instead of a path check; a realistic team boundary |
| <a id="d36"></a>D36 | The showcase is a static site on Vercel's free tier | Always on at no cost, with a preview per pull request, at the apex `yaafsome.fyi` (D38); Vercel does not run the shop, which stays on AWS-shaped infrastructure |
| <a id="d37"></a>D37 | The project is planned in chat: questions, then one line per decision in this file; no ADRs, journal or separate milestones | The owner's way of working from 2026-10-08; one place to read |
| <a id="d38"></a>D38 | The domain `yaafsome.fyi` (Cloudflare Registrar and DNS): the apex for the showcase, one level of subdomains for the demo (`shop`, `argocd`, `grafana`, and `check` for the edge test); the tunnel, hostnames and Access rules are set in the Cloudflare dashboard by a written runbook, not in code | One permanent name for everything presented; free certificates cover one subdomain level only; dashboard setup is one secret and no state to keep, where OpenTofu would need an API token and a permanent state store |
| <a id="d39"></a>D39 | The platform is disposable, the data is not. Floci runs in memory and is never restarted on its own; `up` re-applies a healthy environment and removes and rebuilds anything else; `down` deletes everything; the k3s repair and `reset` are gone. Orders and carts survive through backups kept outside the environment (D42). *Amended 2026-10-08:* first written as "nothing persists" | Rebuilding the platform from git is simpler than repairing it and its duration is the measured recovery time; a company that loses its customers' orders in a disaster does not survive it, so the data gets its own lifecycle |
| <a id="d40"></a>D40 | Removed: the EC2 workstation, the S3 + CloudFront portal (`static-site`), floci-dash and Headlamp. Their guides stay as records; the code is at `c4c44b0` | Nobody can open them from a cloud session, and the stories they told (logging in to EC2, a static site, a console) are not the two clients' story. Fewer parts to keep working |
| <a id="d41"></a>D41 | Agents run the delivery loop in `CLAUDE.md`: check, draft PR, a separate cold review, then auto-merge (squash) gated on the required checks, then the plan updated and the next item started; they stop for open questions, decision changes, money, real AWS, secrets, settings or data deletion | The owner works by planning in chat, not by pressing merge; GitHub's auto-merge makes "never merge red" a property of the platform rather than of the agent's care |
| <a id="d42"></a>D42 | The shop keeps real data: orders in RDS PostgreSQL and carts in ElastiCache, both on Floci and created by the foundation root; never card numbers. Backups are `age`-encrypted dumps on GHCR (OCI artifacts), taken before every teardown and restored by `up`; a canary drill measures RTO and RPO | Managed data services with their own lifecycle are the AWS pattern, and the drill turns "we have backups" into a number. GitHub cannot bill without a card; R2 needs one, can bill and lacks versioning and Object Lock ([research](docs/research/2026-10-08-hosting-alternatives.md)) |
| <a id="d43"></a>D43 | Floci stays the foundation, for every PR, merge and demo. Real-AWS evidence comes only from borrowed vendor sandboxes (the free AWS Builder Center sandbox first), recorded as *verified on real AWS (sandbox, date)* | Floci is the only free emulator that runs EKS, RDS, ElastiCache and IAM enforcement; LocalStack's free plan excludes them. The owner's account has no hard spending cap (AWS's 2026 spend limits are for new sign-ups only), so it stays out (D20) |
| <a id="d44"></a>D44 | In a cloud session, `up` builds the AWS layer only (automatically on a cgroup v1 host, or with `--aws-only`) and `check` validates the manifests offline; the cluster, Argo CD and the shop are proved on the arm64 runner | Kubernetes 1.35+ refuses cgroup v1, and the session also blocks pod networking and image pulls inside k3s; forcing it relies on a fallback due to be removed in 1.38 |
| <a id="d45"></a>D45 | Live demos are attended and time-boxed runs (up to 6 h), plus a recorded walkthrough on the showcase; jobs are never looped to look always-on | No free host runs the arm64 shop all the time without a billable account, and GitHub's terms allow Actions for building and testing, not hosting |
| <a id="d46"></a>D46 | Agents reach real AWS only through the `yaaf-sandbox` profile in `~/.aws`, signed in with `aws login --remote` to a borrowed sandbox (12-hour console credentials, a refresh token removed by `aws logout`, no access keys). Before any tools: the owner's account is refused if `YAAF_OWNER_ACCOUNT_ID` is set, and the owner gives the sandbox's ID from its own page. Then the AWS Agent Toolkit (skills, the AWS MCP server); AWS's agent rules sit in `CLAUDE.md` under markers, adapted (OpenTofu) and below the project's own | Real-AWS evidence (D43) without long-lived credentials or the owner's account, with emulator and real credentials in separate files by construction |

## Log

One line per merged change. History before 2026-10-03 is at the tag `archive/windows-era`.

- 2026-09-16 to 09-21: IaC on Floci, CI to GHCR, GitOps with Argo CD and the bot, the first failure exercise ([postmortem](docs/postmortems/2026-09-21-phase1-bad-emailservice.md))
- 2026-09-24: environment reset to three roots with state in S3; floci-dash; the portal; the EC2 workstation reached three ways; the IAM drill; upstream findings drafted
- 2026-10-01: the pipeline standard (D24), every gate proved against a planted fault
- 2026-10-03: handoff to the Mac; an architecture review by 104 agents produced D25 to D29
- 2026-10-04: `mise.toml`, the lockfile and the tasks; `up` built everything from nothing on the Mac (PR #35)
- 2026-10-05: app-of-apps and Gateway API; a merged change reached the live Application in 54 s with no `tofu apply` (PR #37)
- 2026-10-05: arm64 images; all 12 published with 24 attestations, verified with `gh attestation verify`; the shop works on the arm64 node (PRs #38 to #40)
- 2026-10-08: the move to cloud sessions; this plan replaces the ADRs, handoff, milestones and journal (stage 0)
- 2026-10-08: the domain `yaafsome.fyi`; the `edge-check` workflow and the tunnel and Access guide (D33 amended, D38)
- 2026-10-08: the delivery loop for agents (D41): review, auto-merge on green, proceed until a question
- 2026-10-08: stage 1, the cloud workbench: the SessionStart hook, no Colima, the platform rebuilt and the data kept (D39), the extras removed (D40); the hosting research and D42 to D45
- 2026-10-08: the sandbox lane prepared: `mise run sandbox`, the AWS Agent Toolkit rules, the guide (D46)
- 2026-10-08: stage 2, the whole environment on an arm64 runner: 207 s from nothing to a healthy shop, proved red against a planted bad image digest
- 2026-10-08: the `environment` gate job, so the rebuild can be a required check; one tested change-detection script
- 2026-10-08: OpenTofu's S3 state lock proved on Floci, with a control run (`scripts/drills/state-lock.sh`)
