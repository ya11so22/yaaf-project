# Home Platform Engineering Project

A personal, portfolio-scoped project for building demonstrable depth in GitHub Actions,
AWS infrastructure-as-code, platform engineering, and MLOps — areas not exercised at my
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

- Terraform IaC for a VPC / EKS-equivalent cluster / ECR-equivalent registry / IAM, developed
  locally against [Floci](https://github.com/floci-io/floci) (a free, MIT-licensed local AWS
  emulator), validated against real AWS at milestone checkpoints.
- GitHub Actions: path-filtered per-service builds, `terraform plan`/`apply` gated by PR/merge,
  OIDC federation to AWS (no long-lived credentials).
- A platform engineering layer: one reusable "golden path" workflow instead of 11 near-identical
  pipelines, policy-as-code guardrails (OPA/`conftest`), ephemeral PR environments.
- MLOps on `app/src/recommendationservice` (the one Python service): PR-triggered train/eval,
  metrics-gated promotion on merge, versioned model artifacts.
- Optional stretch: distributed tracing (OpenTelemetry) across all five languages.

Full phased roadmap, cost guardrails, and the practices that run across every phase (ADRs,
deliberate failure exercises, DORA metrics on the pipeline itself, a threat model, and a goal of
one piece of external validation) are documented in the ADRs below and will be expanded as each
phase starts.

## Status

Floci is not yet running locally. This repository is currently scaffolding: directory layout,
ADRs, and the vendored target app / skills. Phase 1 (Terraform + GitHub Actions foundation)
starts once Floci is set up.

## Repository layout

| Path | What lives here |
|---|---|
| `/app` | Vendored Online Boutique (Google's code — see Attribution) |
| `/adr` | Architecture Decision Records — written before implementation, not after |
| `/infra` | Terraform modules (VPC, cluster, registry, IAM) — Phase 1 |
| `/pipelines` | Reusable/callable GitHub Actions workflows — Phase 2 golden path |
| `/policy` | Policy-as-code (OPA/`conftest`) — Phase 2 |
| `/platform` | Platform-layer docs/tooling (ephemeral env lifecycle, service catalog stretch) |
| `.github/workflows` | CI/CD workflow definitions |
| `.claude/skills` | Vendored Matt Pocock engineering/productivity skills for Claude Code |
| `CLAUDE.md` | Per-repo config for those skills (issue tracker, triage labels, domain docs) |
| `docs/agents` | Config files `CLAUDE.md` points to — issue tracker, triage labels, domain docs layout |
| `CONTEXT.md` | This project's own domain glossary (not `/app`'s — that's upstream) |

## Architecture Decision Records

- [ADR-0001: Use an existing open-source app as the target codebase](adr/0001-target-application-choice.md)
- [ADR-0002: Floci-first local AWS emulation, with periodic real-AWS validation milestones](adr/0002-aws-emulation-strategy.md)
- [ADR-0003: Ephemeral EKS over ECS Fargate as the compute target](adr/0003-eks-ephemeral-vs-ecs-fargate.md)

New decisions use [`adr/0000-template.md`](adr/0000-template.md), written *before* asking Claude
Code to implement.
