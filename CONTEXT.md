# Home Platform Engineering Project

Platform/infra/CI-CD/MLOps tooling built around a vendored target application (`/app`, Google's
Online Boutique — see `README.md` for scope and attribution). This file defines terminology
specific to the platform work; it does not describe `/app` itself, which is upstream code.

## Language

Terms are added as they are resolved (via `/domain-modeling`), not written speculatively.

- **App team**: the Claude agents that change `app/src` and open PRs. A simulated team; see
  `CONTRIBUTING.md`.
- **Platform engineer**: the DevOps owner of infrastructure, pipelines, policy and environments;
  the code owner for everything outside `app/src`.
- **Environment**: where a deployment runs. Exactly two: **dev** (Floci, `infra/environments/floci`)
  and **milestone** (real AWS, `infra/environments/aws-milestone`). There is no production.
- **Milestone deploy**: the brief, real-AWS deployment used to validate what the emulator cannot,
  torn down straight after (ADR-0002, ADR-0003).
- **Promotion**: deploying the same image *digest* that was proven in dev to milestone. Tags are
  per-commit SHAs; the digest is what is promoted.
- **Smoke test**: the infra pipeline's throwaway-Floci run: apply from scratch, a re-plan that must
  show no changes, then destroy. It proves the code applies, not that it is secure.
- **Gate job**: an always-running job (`build`, `infra`) that is the single required check for its
  pipeline, so PRs that touch nothing relevant still report it.
- **Golden path**: the single, reusable, parameterised build workflow that Phase 2 extracts from
  `build.yml`, replacing per-service pipelines.
- **Floci**: the local AWS emulator. It stores IAM, ECR and cluster metadata persistently in local
  development and is fresh in every CI run. It does not enforce IAM trust policies.
