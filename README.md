# Home Platform Engineering Project

A portfolio and learning project: a fictional card-payments retailer moves its storefront to AWS, and this repository
is that engagement, designed, built, operated and broken on purpose, with every decision written down. It targets
DevOps and platform roles now and Solutions Architect roles next
([ADR-0021](adr/0021-project-purpose-scenario-and-scope.md)).

Everything runs on a **local AWS** ([Floci](https://github.com/floci-io/floci), a free emulator) on one machine. Nothing
billable is ever created on real AWS ([ADR-0020](adr/0020-zero-spend-real-aws-lane.md)); where Floci differs from AWS,
the difference is written down.

## Run it

On a Mac with a container runtime, OpenTofu, the AWS CLI and `kubectl`: the environment is brought up and down by four
small tasks (`up`, `down`, `reset`, `check`) described in [`docs/mac-migration.md`](docs/mac-migration.md), with a manual
sequence in [`infra/README.md`](infra/README.md). Picking the project up? Start with [`HANDOFF.md`](HANDOFF.md).

Once up, everything is on loopback:

| URL | What |
|---|---|
| `http://<id>.cloudfront.localhost:4566/` | The portal: a static site in S3 behind CloudFront, linking to everything else |
| http://localhost:9877 | An AWS-console-style dashboard for the local AWS (floci-dash) |
| http://argocd.localhost:8080 | Argo CD, reconciling the cluster from git |
| http://headlamp.localhost:8080 | A read-only view of the EKS cluster |
| http://shop.localhost:8080 | The app: Online Boutique, through an ALB and Traefik |

And from a terminal: `aws --profile floci s3 ls`, `kubectl get pods -A`. Details: [`infra/README.md`](infra/README.md).

## What is here

- **Infrastructure as code** (OpenTofu, [ADR-0005](adr/0005-opentofu-over-terraform.md)) in three layered roots:
  a state bucket, the account-level infrastructure (VPC, EKS, ECR, IAM, an ALB, a CloudFront site) with state in S3
  and native locking, and what runs in the cluster ([ADR-0022](adr/0022-the-local-aws-environment.md)).
- **CI on GitHub Actions**: path-filtered image builds to GHCR with content-hash tags, a Trivy scan, an
  infrastructure pipeline that plans and smoke-tests on a fresh Floci, and a shared pre-commit gate
  ([ADR-0023](adr/0023-build-and-delivery.md), [ADR-0009](adr/0009-local-pre-gate.md)).
- **GitOps delivery**: Argo CD deploys from git; a bot pull request bumps image pins after each build; rollback is
  reverting the source change, learned in a [deliberate failure exercise](docs/postmortems/2026-09-21-phase1-bad-emailservice.md).
- **Least-privilege identity**: GitHub Actions federates into AWS with OIDC and three narrowly trusted roles, no
  stored keys ([ADR-0006](adr/0006-github-oidc-role-design.md)).
- **The architecture track** (starting): requirements, views, a Well-Architected review with a findings register,
  reliability, cost, migration and security designs ([`docs/architecture/`](docs/architecture/README.md)). Each
  claim is labelled *designed*, *verified on Floci* or *verified on real AWS*.
- **Guides** ([`docs/guides/`](docs/guides/README.md)): what each piece is, why it was done this way, and what to watch
  out for.

## Where it is going

1. The Mac era ([ADR-0025](adr/0025-tool-versions-and-tasks-in-mise.md) to
   [0029](adr/0029-gateway-api-for-ingress.md)): one `mise.toml`, Argo CD Applications in git, Gateway API, arm64-only images.
2. Close Phase 1: threat model, a pre-merge deploy check, a demo.
3. A library of failure scenarios, each specified before it is run and reported after
   ([ADR-0028](adr/0028-scenario-library.md)).
4. Phase 2, operate it: observability, SLOs and alerts, policy as code, then the scenarios that need monitoring.
5. Requirements, architecture views, Well-Architected review, cost model, DR design, an interview kit.

The shopping-assistant migration from Google Cloud is a backlog item outside the finish line
([ADR-0021](adr/0021-project-purpose-scenario-and-scope.md), amended).

Checklist: [`docs/milestones.md`](docs/milestones.md). Session notes: [`docs/journal/`](docs/journal/); earlier history at the tag `archive/windows-era`.

## How the team works (simulated)

The "app team" is a set of Claude agents that change `app/src` through pull requests; I am the platform engineer and
code owner of everything else. One GitHub identity does both, so required reviews cannot be enforced yet;
`CODEOWNERS` records the intent. Working rules: [`CLAUDE.md`](CLAUDE.md).

## Repository layout

| Path | What lives here |
|---|---|
| `adr/` | Decisions, written before the work. [Index](adr/README.md) |
| `infra/` | The local AWS (`environments/dev`: compose file and three OpenTofu roots) and the modules |
| `deploy/` | What Argo CD deploys: the `dev` overlay with committed image pins, ingress rules, RBAC |
| `scripts/` | `check` (the pre-commit gate, also run by CI) and `drills/` (on-demand demonstrations) |
| `.github/` | Workflows and their scripts, with tests |
| `app/` | Vendored Online Boutique (Google's code; see Attribution) |
| `docs/architecture/` | The architecture track |
| `docs/guides/` | Explanations for learning and interviews |
| `docs/journal/`, `docs/milestones.md`, `docs/postmortems/` | What happened, progress, failure write-ups |
| `docs/research/` | Research behind the decisions, and the drafted Floci fix |
| `HANDOFF.md`, `docs/mac-migration.md` | Current state, next steps, and how to rebuild the tooling on the Mac |
| `CONTEXT.md` | This project's glossary |

## Attribution

- **`app/`** is [Google's Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo), Apache-2.0,
  vendored from upstream commit `72ba613a05f7fcee51cf1d0badff401b6ae7074d` and kept to `src/`, `protos/` and
  `kustomize/` (the Google Cloud tooling was removed). **That code is Google's.** Files the simulated app team changed
  carry a modification notice, as Apache-2.0 requires. See `app/LICENSE`.
- Everything else is original work for this project.
