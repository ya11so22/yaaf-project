# Guide: The CI/CD pipeline standard, and how to build the next pipeline

**Related:** [ADR-0024](../../adr/0024-ci-cd-pipeline-standard.md), [ADR-0023](../../adr/0023-build-and-delivery.md),
[research](../research/2026-09-24-ci-cd-pipeline-research.md), [`.github/workflows/`](../../.github/workflows/README.md)
**Evidence:** checks run locally and gates proven against planted faults (2026-10-01); the workflows themselves are proven
by their first runs on GitHub.

## The idea

A pipeline has two jobs: **give fast, trustworthy feedback on every change** (CI), and **turn an approved change into what
runs, safely** (CD). Two things make it trustworthy. First, it checks what matters for this code. Second, it cannot itself
be used to attack you: the pipeline holds the keys to your registry and your cluster, and CI systems are now the main
target of supply-chain attacks.

## How it works here

```
pull request ──► check   (seconds)  fmt · script tests · manifest schemas · zizmor · actionlint · gitleaks
            ├──► build   (minutes)  changed services: build · scan · gate on new CRITICAL      (nothing pushed)
            └──► infra   (minutes)  fmt · validate · plan (PR comment) · IaC misconfig scan · Floci smoke test

merge to main ─► build: build · scan · gate · push by digest · provenance + SBOM attestations
                   └─► pins: bot PR pins tag@digest in deploy/dev ─► merge ─► Argo CD deploys it

weekly ─► rescan deployed images · scorecard · GHCR cleanup ·  Dependabot (actions, compose images, providers)
```

`build`, `infra` and `check` are the three required checks; each ends in a **gate job** that always runs, so a pull request
that touches nothing relevant still reports green.

## The checklist for a new workflow

Copy this into the next pipeline (for example a deploy pipeline for real AWS, or a pipeline for a new component):

1. `permissions: {}` at the top; each job lists only what it needs, with a comment saying why for each `write`.
2. Actions pinned by full SHA with `# vX.Y.Z`; tool containers pinned by digest. Resolve the SHA from the tag yourself
   (`gh api repos/<owner>/<repo>/git/ref/tags/<tag>`, dereferencing annotated tags); never write one from memory.
3. `actions/checkout` with `persist-credentials: false` unless the job must push.
4. No `pull_request_target`, no `workflow_run`. Anything from the event (titles, branch names, comment bodies) reaches
   `run:` only through `env:`.
5. Every job has `timeout-minutes`; `concurrency` cancels superseded PR runs and never `main` runs.
6. If the workflow is a required check: no workflow-level `paths:` filter; detect changes in a job, and end in a gate job
   with `if: always()`.
7. Anything that produces an artifact others will run: build once, on `main`, push by digest, attest provenance (and an
   SBOM), and refer to it by digest afterwards.
8. Repeated logic becomes a **reusable workflow** (`workflow_call`) or a composite action, not a copy.
9. Run `scripts/check` before pushing: `zizmor` and `actionlint` will tell you what you missed.

## Why this way

- **Pull requests never push images.** Images that can reach the cluster must come from reviewed code built by `main`.
  Before, a pull request could push an image under a content tag that `main` would then reuse without rebuilding.
- **Pins by digest.** A tag on GHCR can be moved; a digest cannot. The pin is written as `tag@digest`, so it stays readable.
- **A ratchet, not a wall.** The upstream app has fixable critical vulnerabilities the project does not own. Failing on all
  of them would block every build; ignoring them all would make the scan decoration. Accepting today's list, with expiry
  dates, and failing on anything new is the standard middle way.
- **Dependabot with a cooldown.** Pins without updates go stale (Trivy here was on a version with a high advisory). Updates
  the same day as a release adopt compromised releases. Seven days' delay sits between the two.
- **One reusable image workflow.** A new service adds a folder, not a pipeline; the build steps live in one reviewed place.

## Watch out for

- **A green check proves only what it checks.** Each new gate here was tested against a planted fault before being trusted.
  Do the same for any new gate: break something on purpose and watch it fail.
- **Baselines go stale fast.** The first baseline was built from the Security tab's older results and missed a critical that
  had appeared since. Build a baseline from a fresh scan with the exact tool version the pipeline uses.
- **Tool lag.** GitHub added the `$/` self-repository syntax in July 2026; `actionlint` does not accept it yet. When two
  tools disagree, pick the form both accept and leave a comment saying when to switch.
- **Suppressions are code.** A `# zizmor: ignore[...]` must start the comment and should say why; an entry in
  `.trivyignore.yaml` must have a statement and an expiry.
- **Attestations prove where an image came from, not that it is safe.** They answer "was this built by our `main` from this
  commit?". Scanning and review answer "is it safe to run?".
- **Scheduled workflows on public repositories** stop after 60 days without repository activity; a quiet project needs a
  push to wake them.

## Check yourself

<details><summary>What does SLSA Build L2 give you, and how do you check it here?</summary>

Signed provenance from a hosted build platform: a tamper-evident record of which workflow, commit and runner produced an
artifact. Here: `gh attestation verify oci://ghcr.io/ya11so22/yaaf-project/<service>@<digest> --repo ya11so22/yaaf-project`.

</details>

<details><summary>Why is pinning actions by tag dangerous, and is pinning by SHA enough?</summary>

Anyone with write access to the action's repository can move a tag, which is how tj-actions (2025) and trivy-action (2026)
were turned into secret stealers. A SHA cannot be moved. It is not enough alone: a pinned SHA still needs updating when
fixes land, which is what Dependabot (with a cooldown) is for.

</details>

<details><summary>Why are `pull_request_target` and `workflow_run` called dangerous?</summary>

They run with the base repository's secrets and write token while being triggered by, or able to reach, code from a pull
request, including from forks. One checkout of the pull request's code in such a workflow hands that code your secrets.

</details>

<details><summary>Your scan finds 40 critical vulnerabilities in code you inherited. What do you gate on?</summary>

Accept the current list explicitly (each with a reason and an expiry), fail on anything new, and drive the list down with
normal work. That makes the gate meaningful from day one without blocking delivery.

</details>
