# Home Platform Engineering Project

A personal, portfolio-scoped project for building demonstrable depth in GitHub Actions,
AWS infrastructure-as-code, platform engineering, and AI infrastructure — areas not exercised at my
day job (Jenkins/OpenShift, on-prem, regulated banking).

## Attribution

- **`/app`** is [Google's Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo)
  (`microservices-demo`), vendored unmodified from upstream commit
  `72ba613a05f7fcee51cf1d0badff401b6ae7074d`, Apache-2.0 licensed. **That code is Google's, not
  mine.** It is used purely as a target application — real polyglot (Go, Java, .NET, Node,
  Python), multi-service complexity to build platform tooling against. See `app/LICENSE` and
  `app/README.md` for upstream's own docs.
- **`/.claude/skills`** vendors the promoted `engineering` and `productivity` skill buckets from
  [Matt Pocock's `skills` repo](https://github.com/mattpocock/skills) (MIT licensed), pinned at
  commit `6654f6b60cd9d5be8b54c6fafe44346dabeb3b76`. These are workflow skills for Claude Code
  (grill → spec → tickets → implement → TDD → review), not part of this project's own work.
  See `.claude/skills/LICENSE-mattpocock-skills`.
- Everything under **`/adr`, `/platform`, `/pipelines`, `/policy`, `/infra`** (once populated) is
  original work for this project.

## What this project is

Not a coding exercise. The target app is deliberately someone else's real, complex system;
the interesting work is the platform layer built around it:

- OpenTofu IaC for a VPC, an EKS-equivalent cluster, an ECR-equivalent registry and IAM,
  developed against [Floci](https://github.com/floci-io/floci) (a free, MIT-licensed local AWS
  emulator) and validated on real AWS at milestone checkpoints.
- GitHub Actions: path-filtered per-service image builds to GHCR, an infrastructure pipeline
  (plan on PR, an apply-from-scratch smoke test), and CD that promotes one image digest from a
  throwaway `dev` environment to a real-AWS `milestone` environment. OIDC federation, so there
  are no long-lived AWS credentials.
- A platform engineering layer: one reusable "golden path" workflow, GitOps with per-PR
  environments, policy-as-code, DORA metrics, and access management for the team.
- Operating it: observability with SLOs and alerts, and an incident drill with a written
  postmortem.
- AI serving on the platform: an open-weight model server with eval-gated promotion, canary and
  rollback, and latency and cost metrics; then classic MLOps on a real recommendation model.
- Optional stretch: distributed tracing (OpenTelemetry) across all five languages.

The pitch: a regulated-grade delivery, operations and AI-serving platform on AWS and EKS
([ADR-0010](adr/0010-us-market-positioning-and-ai-phases.md)). Every decision is an ADR written
before the work, every step a journal entry, every milestone a checkbox. See "How this compares
to live infrastructure" below for what is deliberately not here.

## How the team works (simulated)

- **App team:** a handful of Claude agents. They change `app/src`, open PRs, and pick up work
  from GitHub Issues labelled `ready-for-agent`. Their PRs are the realistic trigger for the
  pipelines, and the reason environments and access management matter.
- **Platform (DevOps):** me. I own the infrastructure, pipelines, policy and environments, and am
  the code owner for everything outside `app/src` (`.github/CODEOWNERS`).
- **What is simulated:** the roles. One GitHub identity does everything through Phase 1, so
  required reviews and permission boundaries cannot be enforced or demonstrated yet; a bot
  identity and per-team cluster access arrive in Phase 2 ([ADR-0008](adr/0008-phase-reslice-cd-and-team-model.md)).

## Phases

Each phase ends with a running app, from commit to deployment, and is demoable on its own.

| Phase | Ends with | State |
|---|---|---|
| 1. Commit to running app | IaC, CI, and minimal CD: images built, deployed to `dev`, promoted to one real-AWS `milestone` deploy | In progress: modules and pipelines are written; CD, first GitHub run, and the real-AWS milestone are open |
| 2. Operate it | Observability, SLOs and alerts, an incident drill and postmortem, GitOps with PR environments, policy-as-code, golden-path workflow, DORA metrics, team access model | Not started |
| 3. AI serving | LLM/model serving on the platform: eval-gated promotion, canary and rollback, latency and cost metrics | Not started |
| 4. MLOps | A real recommendation model: train/eval on PR, registry, metrics-gated promotion, drift monitoring | Not started |

Checklist: [`docs/milestones.md`](docs/milestones.md). Narrative: [`docs/journal/`](docs/journal/).

## How this compares to live infrastructure

The project mirrors how infrastructure is built and changed (IaC, CI gates, least-privilege
identity, decision records) well, and how it is run (deploy, observe, operate) only partly. Some
gaps are deliberate (no permanent production, no public traffic); the rest are scheduled. The
scorecard, with reasons, is in [`docs/live-infra-gap-analysis.md`](docs/live-infra-gap-analysis.md).

## Status

The repository is public, `main` is protected (PRs only, with `build`, `infra` and `check` required),
and the 12 service images are public on GHCR. Floci runs locally with persistent storage
(`infra/environments/floci/compose.yaml`). The VPC, EKS-equivalent, ECR-equivalent and GitHub OIDC
modules are applied and verified against it: `kubectl` reaches the cluster and images push and
pull. The `build`, `infra` and `check` workflows have run and passed on GitHub; the weekly
`cleanup` workflow has not run yet. Nothing is deployed to the cluster yet. Still to do, in order:
CD (deploy overlays and a deploy workflow), then the budget alarm and the real-AWS milestone.

## Repository layout

| Path | What lives here |
|---|---|
| `/app` | Vendored Online Boutique (Google's code — see Attribution) |
| `/adr` | Architecture Decision Records — written before implementation, not after |
| `/infra` | OpenTofu modules (VPC, cluster, registry, IAM) and the `floci` / `aws-milestone` environments: Phase 1 |
| `/deploy` | Kustomize overlays for `dev` and `milestone`, images pinned by digest (Phase 1, not yet created) |
| `/pipelines` | Reusable/callable GitHub Actions workflows — Phase 2 golden path |
| `/policy` | Policy-as-code (OPA/`conftest`) — Phase 2 |
| `/platform` | Platform-layer docs/tooling (ephemeral env lifecycle, service catalog stretch) |
| `.github/workflows` | CI/CD workflows (`build`, `infra`, `cleanup`) and `.github/scripts` (change detection and its tests) |
| `.claude/skills` | Vendored Matt Pocock engineering/productivity skills for Claude Code |
| `CLAUDE.md` | Per-repo config for those skills, plus the documentation-practice convention |
| `docs/agents` | Config files `CLAUDE.md` points to — issue tracker, triage labels, domain docs layout |
| `CONTEXT.md` | This project's own domain glossary (not `/app`'s — that's upstream) |
| `docs/journal` | Dated, one-per-step narrative log of what happened and why |
| `docs/milestones.md` | Phase-by-phase progress against the "independently demoable" bar |
| `docs/live-infra-gap-analysis.md` | Honest comparison with live infrastructure: what is built, deliberate, scheduled, or unproven |
| `docs/postmortems` | Write-ups from each phase's deliberate failure exercise |

## Architecture Decision Records

- [ADR-0001: Use an existing open-source app as the target codebase](adr/0001-target-application-choice.md)
- [ADR-0002: Floci-first local AWS emulation, with periodic real-AWS validation milestones](adr/0002-aws-emulation-strategy.md)
- [ADR-0003: Ephemeral EKS over ECS Fargate as the compute target](adr/0003-eks-ephemeral-vs-ecs-fargate.md)
- [ADR-0004: Split Terraform state/execution strategy — local for Floci, HCP Terraform for the AWS milestone environment](adr/0004-tfstate-backend-strategy.md)
- [ADR-0005: OpenTofu over Terraform as the IaC CLI](adr/0005-opentofu-over-terraform.md)
- [ADR-0006: GitHub Actions federates into AWS via OIDC with three least-privilege roles](adr/0006-github-oidc-role-design.md)
- [ADR-0007: Split CI into build and infra pipelines; images live on GHCR; Floci only validates infra](adr/0007-ci-split-ghcr-and-floci-scope.md)
- [ADR-0008: Phases end in a running app; named environments; push-based CD; team model](adr/0008-phase-reslice-cd-and-team-model.md)
- [ADR-0009: A shared local pre-gate, with CI as the source of truth](adr/0009-local-pre-gate.md)
- [ADR-0010: Position for the US DevOps, platform and AI-infrastructure market; reorder the phases](adr/0010-us-market-positioning-and-ai-phases.md)
- [ADR-0011: CD design: image identity, deploy scope and milestone state](adr/0011-cd-image-identity-scope-and-state.md)

New decisions use [`adr/0000-template.md`](adr/0000-template.md), written *before* asking Claude
Code to implement.
