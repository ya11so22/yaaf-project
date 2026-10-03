# Home Platform Engineering Project

Platform, infrastructure, delivery and architecture work built around a vendored target application (`/app`, Google's
Online Boutique; see `README.md` for scope and attribution). This file defines terminology specific to the platform
work; it does not describe `/app` itself, which is upstream code.

## Language

Terms are added as they are resolved (via `/domain-modeling`), not written speculatively.

**The project**

- **Engagement**: the fictional card-payments retailer's move to AWS, which frames the architecture track from
  discovery to the second review (ADR-0021).
- **Evidence label**: every claim is **designed**, **verified on Floci** or **verified on real AWS** (ADR-0021).
- **Guide**: a `docs/guides/` page that teaches one concept: the idea, how it works here, why this way, what to watch
  out for, and self-check questions. ADRs record decisions; guides teach.
- **App team**: the Claude agents that change `app/src` and open PRs. A simulated team; see `CLAUDE.md`.
- **Platform engineer**: the owner of infrastructure, pipelines, delivery and environments; the code owner for
  everything outside `app/src`.

**The environment**

- **AWS**: the cloud layer (IAM, VPC, S3, CloudFront, ELB, ECR, EKS). Backed by the local **Floci**; nothing billable
  is created on real AWS. Say "AWS" for the layer, and name the thing when it matters: the **EKS cluster**, a
  **workload** in it, or the **emulator** for Floci's own behaviour (ADR-0022).
- **Floci**: the local AWS emulator, long-lived on the owner's machine with persistent storage, and fresh in every CI
  run. By default it does not enforce IAM policies or trust conditions; it has an enforcement mode
  (`docs/guides/iam-policies-and-trust.md`).
- **floci-dash**: the dashboard for Floci, modelled on the AWS Management Console (ADR-0022).
- **Environment**: what OpenTofu provisions on top of AWS. **dev** is the only one; there is no production.
- **Root**: one OpenTofu working directory with its own state. dev has three, applied in order: **bootstrap** (the
  state bucket), **foundation** (the account-level infrastructure), **cluster** (what runs inside EKS).
- **State bucket**: `yaaf-dev-tfstate` on Floci, holding the foundation and cluster state with an S3 lock file.
- **Workstation**: the EC2 instance the foundation root creates to log in to; reachable through the dashboard terminal, SSH
  or SSM Run Command (ADR-0022).
- **Scenario**: a failure exercise kept as a folder, `docs/scenarios/<name>/`: a spec written before it is run, a script that
  injects the fault, and a dated report in `docs/postmortems/` for each run (ADR-0028).
- **Portal**: the static website (S3 behind CloudFront) that links to every local endpoint.
- **Real AWS**: not used. The rule is that nothing billable is ever created there; the "zero-spend lane" of ADR-0020 was
  rejected on 2026-10-03 and anything real waits until the project is complete.

**Build and delivery**

- **Content tag**: an image tag `content-<hash>`, the git tree hash of a service's build context, so unchanged
  services keep their tag (ADR-0023).
- **Image pin**: the committed content tag for a service in `deploy/dev`; what Argo CD deploys. Pins are derived from
  the source, so rollback is reverting the source change: a pin-only revert is undone by the next bump.
- **Argo CD**: runs in the cluster and reconciles workloads from git every 60 seconds; nothing pushes into the
  cluster (ADR-0023).
- **App-of-apps**: one root Argo CD Application that points at `deploy/apps/`, where each other Application is a file,
  so platform changes arrive by pull request (ADR-0026).
- **Gateway API**: the Kubernetes routing API that replaces `Ingress` here: the platform owns a **Gateway**, each team owns
  **HTTPRoutes** attached to it (ADR-0029, `docs/guides/gateway-api.md` once written).
- **Smoke test**: the infra pipeline's run on a fresh Floci: bootstrap, apply the foundation, a re-plan that must show
  no changes, destroy. It proves the code applies, not that it is secure.
- **Digest pin**: an image pin written as `tag@sha256:...`, readable and immutable; what the bot writes (ADR-0024).
- **Attestation**: a Sigstore-signed statement stored on GitHub about an image digest: its SLSA build provenance and its
  SBOM. Checked with `gh attestation verify` (ADR-0024).
- **Scan ratchet**: the build fails on a fixable CRITICAL vulnerability unless it is an accepted, unexpired entry in
  `.trivyignore.yaml`, so new findings fail and known ones are tracked (ADR-0024).
- **Gate job**: an always-running job (`build`, `infra`, `check`) that is the single required check for its pipeline,
  so PRs that touch nothing relevant still report it.
