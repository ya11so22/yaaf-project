# Home Platform Engineering Project

Platform/infra/CI-CD/AI-infrastructure tooling built around a vendored target application (`/app`, Google's
Online Boutique — see `README.md` for scope and attribution). This file defines terminology
specific to the platform work; it does not describe `/app` itself, which is upstream code.

## Language

Terms are added as they are resolved (via `/domain-modeling`), not written speculatively.

- **App team**: the Claude agents that change `app/src` and open PRs. A simulated team; see
  `CONTRIBUTING.md`.
- **Platform engineer**: the DevOps owner of infrastructure, pipelines, policy and environments;
  the code owner for everything outside `app/src`.
- **AWS**: the cloud layer (IAM, VPC, ECR, EKS). Backed by a long-lived local Floci for now; real AWS
  is a later second backend. Say "AWS" for the layer, and name the thing when it matters: the
  **EKS cluster**, a **workload** in it, or the **emulator** for Floci's own behaviour (ADR-0013).
- **Environment**: what OpenTofu provisions on top of AWS. **dev** (`infra/environments/floci`) is
  the only one now; **milestone** (`infra/environments/aws-milestone`) waits for real AWS
  (ADR-0012). There is no production.
- **Milestone deploy**: the brief, real-AWS deployment used to validate what the emulator cannot,
  torn down straight after (ADR-0002, ADR-0003).
- **Content tag**: an image tag `content-<hash>`, the git tree hash of a service's build context, so
  unchanged services keep their tag (ADR-0011).
- **Image pin**: the committed content tag for a service in `deploy/dev`; what Argo CD deploys. Pins are
  derived from the source, so rollback is reverting the source change: a pin-only revert is undone by the
  next bump.
- **Argo CD**: runs in the cluster and reconciles workloads from git; nothing pushes into the cluster
  (ADR-0013).
- **Promotion**: deploying the same image proven in dev to milestone (by content tag and digest).
- **Smoke test**: the infra pipeline's throwaway-Floci run (a fresh emulator per CI run, unlike the
  long-lived AWS): apply from scratch, a re-plan that must
  show no changes, then destroy. It proves the code applies, not that it is secure.
- **Gate job**: an always-running job (`build`, `infra`) that is the single required check for its
  pipeline, so PRs that touch nothing relevant still report it.
- **Golden path**: the single, reusable, parameterised build workflow that Phase 2 extracts from
  `build.yml`, replacing per-service pipelines.
- **Floci**: the local AWS emulator that backs AWS. It stores IAM, ECR and cluster metadata persistently in local
  development and is fresh in every CI run. It does not enforce IAM trust policies.
