# Milestones

Progress against the finish line in [ADR-0021](../adr/0021-project-purpose-scenario-and-scope.md): each phase is
demoable on its own. Ticked as work lands; the narrative is in [`docs/journal/`](journal/). The detailed history of Phase 1 (journal
entries, archived ADRs, the Windows scripts) is at the tag `archive/windows-era`.

## Phase 1: commit to running app

### Done

- [x] **Infrastructure as code on the local AWS**: VPC, EKS, ECR, IAM (GitHub OIDC roles, the kubectl user) and an
      ingress ALB as OpenTofu modules, applied to Floci (2026-09-16 to 09-21)
- [x] **CI**: path-filtered builds to GHCR with content-hash tags and Trivy; an infra pipeline with a plan comment and a
      Floci smoke test; the shared pre-gate; weekly GHCR cleanup. First green run on PR #1 (2026-09-20)
- [x] **Repository**: public, history scanned with gitleaks, `main` protected with `build`, `infra` and `check`
      required, actions pinned to SHAs, GHCR packages public (2026-09-20)
- [x] **GitOps delivery**: Argo CD installed by OpenTofu reconciles the app, Traefik, Headlamp and ingress rules from
      git; a GitHub App bot opens image-pin PRs with auto-merge; confirmed end to end (2026-09-21)
- [x] **Failure exercise and postmortem**: a bad emailservice, recovered; rollback is reverting the source
      ([postmortem](postmortems/2026-09-21-phase1-bad-emailservice.md), 2026-09-21)
- [x] **Environment reset** ([ADR-0022](../adr/0022-the-local-aws-environment.md), 2026-09-24): three roots (bootstrap,
      foundation, cluster) with state in S3 on Floci and native locking; floci-dash; a static portal on S3 and
      CloudFront; everything on loopback; clean up/down scripts with a reset (Windows; rebuilt on the Mac). Built from nothing, re-run with no
      changes, and every endpoint checked
      (journal)
- [x] **EC2 workstation, reached three ways** (2026-09-24): the dashboard's web terminal, SSH with a dedicated key, and SSM
      Run Command, all tested; created and destroyed cleanly by OpenTofu
      ([guide](guides/reaching-an-ec2-instance.md)). Session Manager's interactive shell is unsupported by Floci
- [x] **IAM behaviour shown on demand** (2026-09-24): `scripts/drills/iam-trust.sh` demonstrates policy enforcement, permission
      boundaries and IRSA trust allow, deny and tamper checks on Floci, and the known gap with forged GitHub tokens
      ([guide](guides/iam-policies-and-trust.md))
- [x] **Upstream findings drafted** (2026-09-24): four Floci and two floci-dash items, none filed
      ([findings](research/2026-09-24-floci-upstream-findings.md))

- [x] **Pipeline standard** ([ADR-0024](../adr/0024-ci-cd-pipeline-standard.md), 2026-10-01): researched against GitHub,
      OpenSSF, SLSA and DORA guidance; PRs no longer push images; `main` publishes by digest with SLSA provenance and an
      SBOM; pins by digest; a Trivy gate that fails on new criticals (baseline from a fresh scan); zizmor and kubeconform in
      the pre-gate; IaC scan; weekly rescan of deployed images; Scorecard; Dependabot with a cooldown; the `workflow_run`
      trigger removed. Gates proven against planted faults ([guide](guides/ci-cd-pipeline-standard.md))

- [x] **Handoff to the Mac** (2026-10-03): history tagged `archive/windows-era`; Windows scripts replaced by guidelines
      ([`docs/mac-migration.md`](mac-migration.md)); docs collapsed to the current decisions; [`HANDOFF.md`](../HANDOFF.md)

### Left

- [x] **The Mac era, step 2** (2026-10-04): ADRs 0025 to 0029 written (2026-10-03); `mise.toml`, the lockfile and the tasks
      `up`, `down`, `reset`, `check` built; `up` builds the whole environment from nothing on the project's own Colima VM
      and every URL answers; `scripts/check` runs the locked binaries; the bump scripts fixed for macOS
      ([journal](journal/2026-10-04-mise-tasks-and-first-up.md))
- [ ] **The Mac era, the rest** ([review](research/2026-10-03-architecture-review.md)), in this order: app-of-apps and Gateway
      API (with the Gateway API guide); the arm64 pipeline with the architecture check, which also fixes the four app pods that
      crash on emulated amd64; the ECR module deleted; `up` made lean with an opt-in `extras` root
- [ ] Threat model (STRIDE) of the pipeline and infrastructure, including the bot App, auto-merge, no-login Headlamp,
      and floci-dash (becomes part of `06-security-and-compliance.md`)
- [ ] Pre-merge deploy check: apply the dev roots to a throwaway Floci in the PR, install Argo CD, sync the PR's
      commit, wait for `Synced` and `Healthy` ([ADR-0023](../adr/0023-build-and-delivery.md) item 8). The first guardrail
      for agent pull requests below
- [ ] **Guardrails for agent pull requests** ([research](research/2026-10-04-reliability-and-ai-change-guardrails.md); ADR first): an agent scope check (only `app/src`), a dependency
      existence and lockfile gate, a pull-request size limit, and SAST as a ratchet on new high findings. Each proven
      against a planted fault
- [ ] Demo: README walkthrough and a short recording

## Real AWS

Nothing billable is ever created on real AWS. The zero-spend lane ([ADR-0020](../adr/0020-zero-spend-real-aws-lane.md))
was rejected on 2026-10-03; anything real is decided once the project is complete.

- [ ] Owner, in the console, whenever convenient: nothing running or billing in any Region; root MFA on and no root keys;
      a zero-spend budget ([guide](guides/aws-cost-safety.md))

## Architecture track

The design side, in AWS's terms ([`docs/architecture/`](architecture/README.md)). Ordered by dependency.

- [x] Scenario chosen: a card-payments retailer, PCI DSS as the control frame (2026-09-24)
- [ ] Requirements and constraints (`00-requirements.md`)
- [ ] Architecture views as diagrams in code (`01-views.md`)
- [ ] Well-Architected review v1 with a findings register (`02-well-architected-review.md`)
- [ ] Reliability and DR: RTO/RPO tiers and cost per tier (`03-reliability-and-dr.md`)
- [ ] Cost model with real pricing (`04-cost-model.md`)
- [ ] Designs only, labelled *designed*: node autoscaling (Karpenter), Spot and Graviton fleets, multi-AZ and
      multi-Region recovery, OpenTelemetry tail sampling; a cost per reliability tier ([research](research/2026-10-04-reliability-and-ai-change-guardrails.md))
- [ ] Migration options with the 7 Rs (`05-migration-options.md`)
- [ ] Security and compliance: the threat model and a PCI DSS control mapping (`06-security-and-compliance.md`)
- [ ] AI architecture: Bedrock against self-hosted serving, the RAG design (`07-ai-architecture.md`)
- [ ] Governance: multi-account layout and guardrails, on paper (`08-governance.md`)
- [ ] Well-Architected review v2 after Phase 2
- [ ] Customer-facing: executive summary, review readout, discovery questions
- [ ] Interview kit: each decision mapped to a pillar and its alternatives; stories from real events here
- [ ] A tally of real US postings for the target roles. Started with 8
      ([research](research/2026-09-24-sa-market-and-project-reality-check.md)); too small to call a tally

## Scenario library ([ADR-0028](../adr/0028-scenario-library.md))

- [ ] Library set up: `docs/scenarios/`, a spec template, `iam-trust.sh` moved into its scenario
- [ ] Scenarios run and reported: configuration drift (in the cluster, and in the cloud layer with
      `tofu plan -refresh-only -detailed-exitcode`); losing the platform (recovery time measured); stuck or lost state; a
      leaked credential; a tag rewrite in the supply chain; overbroad OIDC trust; a mislabelled image
- [ ] After monitoring: a failing dependency seen as an SLO burn; capacity exhaustion; a cascading failure with retries at
      one layer only (AWS REL05-BP03); a traffic spike absorbed by a HorizontalPodAutoscaler under load ([research](research/2026-10-04-reliability-and-ai-change-guardrails.md))

## Phase 2: operate it

- [ ] Observability: metrics and dashboards for the app
- [ ] SLOs and alerts on them: multiwindow, multi-burn-rate (Google SRE Workbook), proved against a planted fault under
      synthetic load ([research](research/2026-10-04-reliability-and-ai-change-guardrails.md))
- [ ] Canary rollouts with automated analysis (Argo Rollouts and Prometheus): the last line of defence for a bad change
- [ ] Policy as code: `conftest` on plans (for example, no wildcard OIDC `sub`) and manifests; an IaC security scan
- [ ] IAM negative tests as a CI regression check: run the parts of `scripts/drills/iam-trust.sh` that need no dev cluster on a fresh Floci
- [ ] An incident drill with a postmortem
- [ ] Deferred, optional: DORA metrics; per-PR environments with an Argo CD `ApplicationSet`

## Backlog: replatform the shopping assistant from Google Cloud to AWS (formerly Phase 3; outside the finish line since 2026-10-03)

- [ ] Implementation ADR: the local model or stub, the provider interface, the data layer
- [ ] `shoppingassistantservice` behind a provider interface: Bedrock (designed) or local (built)
- [ ] PostgreSQL with pgvector for retrieval, and Secrets Manager for its password, on Floci
- [ ] Catalogue embeddings loaded by a repeatable job; the assistant works end to end locally
- [ ] Backup-and-restore drill measured against the scenario's RPO, with a postmortem
- [ ] README attribution updated: this service is modified from upstream

## Learning guides ([index](guides/README.md))

- [x] Guide format and index; [staying at $0 on AWS](guides/aws-cost-safety.md) (2026-09-24)
- [x] [The local AWS environment](guides/local-aws-environment.md), [Kubernetes probes](guides/kubernetes-probes.md),
      [Reaching an EC2 instance](guides/reaching-an-ec2-instance.md) and
      [IAM policies, boundaries and trust](guides/iam-policies-and-trust.md) (2026-09-24)
- [ ] Backfill: GitHub OIDC, GitOps with Argo CD, content-hash tags

## Standing goals

- [ ] One piece of external validation: a Floci upstream contribution. Drafts are ready in
      [the findings](research/2026-09-24-floci-upstream-findings.md), led by the CloudFront tag bug, whose cause is a
      one-line key mismatch in the source (a good first pull request); earlier candidates: the k3s restart failures
- [ ] A deliberate failure exercise and postmortem per phase
