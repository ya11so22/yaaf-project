# ADR-0024: The CI/CD pipeline standard

**Status:** accepted (refines [ADR-0023](0023-build-and-delivery.md) items 1 and 3; ADR-0023's delivery model is unchanged; the Trivy scan runs the locked `trivy` binary instead of `trivy-action` since [ADR-0025](0025-tool-versions-and-tasks-in-mise.md))
**Date:** 2026-09-24

## Context

The owner asked for the pipeline to be reviewed against how GitHub Actions pipelines *should* be built, fixed where it
falls short, and written up as a standard that later pipelines in this project can copy. The research, with sources, is in
[`docs/research/2026-09-24-ci-cd-pipeline-research.md`](../docs/research/2026-09-24-ci-cd-pipeline-research.md). The
points that drive this decision:

- **Supply-chain attacks on CI are the main threat in 2025 to 2026.** `tj-actions/changed-files` (March 2025) and the
  TeamPCP compromise of `aquasecurity/trivy-action` and `setup-trivy` (March 2026: 76 of 77 tags force-pushed to a
  credential stealer) both hit repositories that referenced actions by tag. This project pins by commit SHA, and the pinned
  `trivy-action` commit was checked on 2026-09-24: it is v0.36.0, published a month after the incident, immutable. The
  project was not exposed. But nothing keeps pins up to date: the scan runs Trivy v0.70.0, which has a high-severity
  advisory (GHSA-mcj4-mphf-j9ff, fixed in 0.71.1).
- **GitHub's hardening guide** asks for: read-only default token, permissions per job, SHA pinning, no untrusted input in
  scripts, avoiding `pull_request_target` and `workflow_run`, OIDC instead of stored cloud keys, `CODEOWNERS` on workflows,
  Dependabot for actions, and OpenSSF Scorecard. **SLSA** Build L2 is signed provenance from a hosted builder; GitHub
  artifact attestations give it for free on public repositories.
- **DORA**: every commit builds, feedback in minutes (10 at most), a broken build is fixed first, trunk-based.
- An audit of the current workflows with `zizmor` (static analysis for Actions) found one high finding
  (`dangerous-triggers`: `bump-images` uses `workflow_run`; guarded, so not exploitable today) and eight medium ones
  (`artipacked`: checkout leaves the token on disk).
- A design flaw found in review: **same-repository pull requests push images to the registry, and `main` reuses them.** The
  content tag is the hash of the service's source folder, so a PR that changes only the build workflow can push an image with
  the right tag but different contents, and `main` then skips its own build and deploys it. The simulated app team opens
  exactly such PRs. Images that can reach the cluster must be built by `main` only.

## Options considered

1. **Keep the pipeline, fix the findings.** Least work; leaves no provenance, no update tool, and the PR-push flaw.
2. **Adopt a platform (Dagger, a hosted CI) instead of Actions.** Adds cost or a new tool without solving the above.
3. **A written standard, applied to every workflow here, with the image build extracted as a reusable workflow** (chosen).
   The reusable workflow is both the template for future services and the SLSA-recommended way to isolate the build.

## Decision

Every workflow in this repository follows these rules, and new workflows start from them
([guide](../docs/guides/ci-cd-pipeline-standard.md)):

**Security baseline**
1. `permissions: {}` at the top of every workflow; each job asks for exactly what it needs.
2. Every third-party action pinned to a full commit SHA with the version in a comment; containers used as tools pinned by
   digest. **Dependabot** keeps them current (weekly, grouped, with a 7-day cooldown so a freshly compromised release is not
   adopted the day it appears). It also watches the compose file's images and the OpenTofu providers.
3. `actions/checkout` with `persist-credentials: false`, except where a job must push with the token it was given.
4. No `pull_request_target`, no `workflow_run`. Untrusted values reach scripts only through `env:`.
5. `zizmor` joins `actionlint` in the pre-gate (`scripts/check`), so workflow security is checked on every commit; in CI it
   runs online, which adds the impostor-commit and known-vulnerable-action audits.

**Build and supply chain**
6. **Pull requests build and scan but never push.** Only `main` pushes images. `main` pushes by digest, then records
   **SLSA build provenance** and a **CycloneDX SBOM** as GitHub artifact attestations (`actions/attest`), verifiable with
   `gh attestation verify`. Attestations are kept in GitHub, not the registry, so they do not count against GHCR retention.
7. The image build is one **reusable workflow** (`reusable-container-image.yml`, `workflow_call`) with the service as input.
   A new service needs a folder and a Dockerfile, not a new pipeline.
8. **Image pins are by digest** (`tag@sha256:…` through kustomize's `digest` field), resolved from the registry when the bot
   writes them, so a moved tag can never change what runs.
9. **Scanning ratchets.** Trivy (pinned to a version with no known advisories) reports HIGH and CRITICAL to the Security tab
   and **fails the build on any fixable CRITICAL** not listed in `.trivyignore.yaml`. That file records today's accepted
   findings, each with a reason and an expiry date, after which the build fails again. A weekly job re-scans the **deployed**
   (pinned) images, since new CVEs appear after build time.
10. The pin bump is the last job of the `main` build (no separate `workflow_run` workflow).

**Verification**
11. `check` (fast, every change) adds manifest validation: every kustomize directory under `deploy/` is rendered and checked
    against the Kubernetes 1.36 schemas with `kubeconform`.
12. `infra` adds an IaC misconfiguration scan (`trivy config`, report-only to the Security tab) beside fmt, validate, plan and
    the Floci smoke test.
13. **OpenSSF Scorecard** runs weekly and on `main`, publishing the repository's supply-chain score.

**Shape** (unchanged, stated for the template)
14. One always-running **gate job** per required workflow (`build`, `infra`, `check`), so path filtering never leaves a
    required check pending. `concurrency` cancels superseded PR runs, never `main` runs. Every job has a `timeout-minutes`.
    Target: PR feedback under 10 minutes.

## Rationale

Each rule answers a named threat or a named practice, and the whole set is what GitHub, OpenSSF and SLSA themselves
recommend, applied at the size of this project. The PR-push fix and digest pins close the one real path by which unreviewed
code could reach the cluster. Provenance and SBOMs cost two steps and give a claim an interviewer can check with one command.
The ratchet turns scanning from decoration into a gate without blocking on upstream debt the project does not own.

## Consequences / trade-offs accepted

- PR builds no longer produce images, so a PR cannot be deployed from the registry before merge. The planned pre-merge
  deploy check (ADR-0023 item 8) will need to load the PR's images into the throwaway cluster directly.
- Images built before this change have no attestations; they gain them when their service next changes.
- The `.trivyignore.yaml` baseline is accepted risk in upstream code, with expiry dates that force a review.
- Not adopted, with reasons: **merge queue** (unavailable for repositories owned by a personal account); **StepSecurity
  harden-runner** (a third-party action with deep runner access, which is itself the risk class this ADR is about);
  **CodeQL on the app** (Google's code, not this project's; zizmor covers the workflows); **cosign keyless signing** (the
  GitHub attestation is Sigstore-signed already).
- Repository settings that would complete the standard are the owner's to change: squash-only merges with linear history,
  Dependabot alerts and security updates, and requiring branches to be up to date before merging.
