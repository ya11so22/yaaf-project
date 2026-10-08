# Home Platform Engineering Project

A portfolio and learning project: a fictional card-payments retailer moves its storefront to AWS, and this repository
is that engagement, designed, built, operated and broken on purpose, with every decision written down. It targets
DevOps and platform roles now and Solutions Architect roles next.

The project simulates the two pressures a real platform lives under:

1. **Developer teams** pushing pull requests all the time, much of it AI-written, which must be caught before it ships
   when it is wrong. That is the DevOps and platform side.
2. **Shop users** bringing traffic spikes, abuse and failures, and the disasters the shop must recover from. SRE
   operates it; the solutions architect decides what it must withstand and at what cost.

Everything runs on a **local AWS** ([Floci](https://github.com/floci-io/floci), a free emulator). Nothing is ever created
on real AWS; where Floci differs from AWS, the difference is written down.

**Start with [`PLAN.md`](PLAN.md)**: the architecture, the stages of work, the open questions and every decision.

## How it runs

There is no long-lived machine. Work happens in Claude Code cloud sessions, and the whole environment is **built from
git and thrown away**: Floci, three OpenTofu roots, EKS on k3s, Argo CD and the shop. Production is *designed* for real
AWS, never built; rebuilding the environment after every merge is the evidence that the design holds (PLAN.md D30 to
D32). The ephemeral-runner workflow, the live demo and the showcase site are stages 2, 4 and 7 of the plan.

In a session, `mise run up` builds it and `mise run down` removes it ([`infra/README.md`](infra/README.md)); a
SessionStart hook installs the locked tools and starts Docker first. From a terminal: `aws --profile floci s3 ls`,
`kubectl get pods -A`.

## What is here

- **Infrastructure as code** (OpenTofu) in three layered roots: a state bucket, the account-level infrastructure (VPC,
  EKS, ECR, IAM, an ALB) with state in S3 and native locking, and what runs in the cluster.
- **CI on GitHub Actions** to a written standard: pull requests build and scan but never push; `main` publishes arm64
  images by digest with SLSA provenance and an SBOM; a Trivy gate that fails on new criticals; zizmor, kubeconform,
  Scorecard and Dependabot ([guide](docs/guides/ci-cd-pipeline-standard.md)).
- **GitOps delivery**: Argo CD deploys from git as an app-of-apps through Gateway API routes; a bot pull request pins
  images by digest; rollback is reverting the source change, learned in a
  [deliberate failure exercise](docs/postmortems/2026-09-21-phase1-bad-emailservice.md).
- **Least-privilege identity**: GitHub Actions federates into AWS with OIDC and three narrowly trusted roles, no stored
  keys ([guide](docs/guides/iam-policies-and-trust.md)).
- **The architecture track** (starting): requirements, views, a Well-Architected review with a findings register,
  reliability, cost, migration and security designs ([`docs/architecture/`](docs/architecture/README.md)). Each claim
  is labelled *designed*, *verified on Floci* or *verified on real AWS*.
- **Guides** ([`docs/guides/`](docs/guides/README.md)): what each piece is, why it was done this way, and what to watch
  out for.

## How the team works (simulated)

The "app team" is Claude agents that change `app/src` through pull requests; I am the platform engineer and code owner
of everything else. Stage 3 of the plan splits the app into its own repository, worked by two agent teams, Checkout and
Catalog. One GitHub identity does every role, so required reviews cannot be enforced; `CODEOWNERS` records the intent.
Working rules: [`CLAUDE.md`](CLAUDE.md).

## Repository layout

| Path | What lives here |
|---|---|
| `PLAN.md` | The architecture, stages, open questions, decisions and log |
| `infra/` | The local AWS (`environments/dev`: compose file and three OpenTofu roots), the modules, and the Floci quirks |
| `deploy/` | What Argo CD deploys: the Applications, the `dev` overlay with committed image pins, the routes |
| `scripts/` | `check` (the pre-commit gate, also run by CI) and `drills/` (on-demand demonstrations) |
| `.github/` | Workflows and their scripts, with tests |
| `app/` | Vendored Online Boutique (Google's code; see Attribution) |
| `docs/architecture/` | The architecture track |
| `docs/guides/` | Explanations for learning and interviews |
| `docs/postmortems/`, `docs/research/` | Failure write-ups; dated research behind the decisions, and the drafted Floci fix |
| `CONTEXT.md` | This project's glossary |

Earlier history: the ADRs, handoff, milestones and journal were folded into the plan on 2026-10-08 and are readable at
commit `c4c44b0`; the Windows era is at the tag `archive/windows-era`.

## Attribution

- **`app/`** is [Google's Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo), Apache-2.0,
  vendored from upstream commit `72ba613a05f7fcee51cf1d0badff401b6ae7074d` and kept to `src/`, `protos/` and
  `kustomize/` (the Google Cloud tooling was removed). **That code is Google's.** Files the simulated app team changed
  carry a modification notice, as Apache-2.0 requires. See `app/LICENSE`.
- Everything else is original work for this project.
