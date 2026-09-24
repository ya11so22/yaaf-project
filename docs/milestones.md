# Milestones

Progress against the finish line in [ADR-0021](../adr/0021-project-purpose-scenario-and-scope.md): each phase is
demoable on its own. Ticked as work lands; the narrative behind each item is in [`docs/journal/`](journal/). Rewritten
on 2026-09-24 when the project was reset and the ADRs consolidated; the detailed history of Phase 1 is in the journal
and in [`adr/archive/`](../adr/archive/).

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
      CloudFront; everything on loopback; clean `dev-up` / `dev-down` with `-Reset`. Built from nothing, re-run with no
      changes, and every endpoint checked
      ([journal](journal/2026-09-24-reset-and-local-aws-rebuild.md))
- [x] **EC2 workstation, reached three ways** (2026-09-24): the dashboard's web terminal, SSH with a dedicated key, and SSM
      Run Command, all tested; created and destroyed cleanly by OpenTofu
      ([guide](guides/reaching-an-ec2-instance.md)). Session Manager's interactive shell is unsupported by Floci
- [x] **IAM behaviour shown on demand** (2026-09-24): `scripts/drills/iam-trust.sh` demonstrates policy enforcement, permission
      boundaries and IRSA trust allow, deny and tamper checks on Floci, and the known gap with forged GitHub tokens
      ([guide](guides/iam-policies-and-trust.md))
- [x] **Upstream findings drafted** (2026-09-24): four Floci and two floci-dash items, none filed
      ([findings](research/2026-09-24-floci-upstream-findings.md))

### Left

- [ ] Threat model (STRIDE) of the pipeline and infrastructure, including the bot App, auto-merge, no-login Headlamp,
      and floci-dash (becomes part of `06-security-and-compliance.md`)
- [ ] Pre-merge deploy check: apply the dev roots to a throwaway Floci in the PR, install Argo CD, sync the PR's
      commit, wait for `Synced` and `Healthy` ([ADR-0023](../adr/0023-build-and-delivery.md) item 8)
- [ ] Demo: README walkthrough and a short recording

## Real AWS: the zero-spend lane ([ADR-0020](../adr/0020-zero-spend-real-aws-lane.md), proposed)

Nothing billable is ever created on real AWS. Revised after the IAM drill: policy, boundary and IRSA trust logic are now
shown locally, so real AWS is needed only to test GitHub's own issuer, and is optional.

- [ ] Owner, in the console: nothing running or billing in any Region; root MFA on and no root keys; a zero-spend
      budget ([guide](guides/aws-cost-safety.md))
- [ ] An IAM-and-STS-only project identity, with a permissions boundary on every role it creates
- [ ] GitHub OIDC trust proven on real AWS: this repository can assume the role, another repository and another branch
      cannot, with logs and CloudTrail event history kept

## Architecture track

The design side, in AWS's terms ([`docs/architecture/`](architecture/README.md)). Ordered by dependency.

- [x] Scenario chosen: a card-payments retailer, PCI DSS as the control frame (2026-09-24)
- [ ] Requirements and constraints (`00-requirements.md`)
- [ ] Architecture views as diagrams in code (`01-views.md`)
- [ ] Well-Architected review v1 with a findings register (`02-well-architected-review.md`)
- [ ] Reliability and DR: RTO/RPO tiers and cost per tier (`03-reliability-and-dr.md`)
- [ ] Cost model with real pricing (`04-cost-model.md`)
- [ ] Migration options with the 7 Rs (`05-migration-options.md`)
- [ ] Security and compliance: the threat model and a PCI DSS control mapping (`06-security-and-compliance.md`)
- [ ] AI architecture: Bedrock against self-hosted serving, the RAG design (`07-ai-architecture.md`)
- [ ] Governance: multi-account layout and guardrails, on paper (`08-governance.md`)
- [ ] Well-Architected review v2 after Phase 3
- [ ] Customer-facing: executive summary, review readout, discovery questions
- [ ] Interview kit: each decision mapped to a pillar and its alternatives; stories from real events here
- [ ] A tally of real US postings for the target roles. Started with 8
      ([research](research/2026-09-24-sa-market-and-project-reality-check.md)); too small to call a tally

## Phase 2: operate it

- [ ] Observability: metrics and dashboards for the app
- [ ] SLOs and alerts on them
- [ ] Policy as code: `conftest` on plans (for example, no wildcard OIDC `sub`) and manifests; an IaC security scan
- [ ] IAM negative tests as a CI regression check: run the parts of `scripts/drills/iam-trust.sh` that need no dev cluster on a fresh Floci
- [ ] An incident drill with a postmortem
- [ ] Deferred, optional: DORA metrics; per-PR environments with an Argo CD `ApplicationSet`

## Phase 3: replatform the shopping assistant from Google Cloud to AWS

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
