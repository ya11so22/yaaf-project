# 2026-10-01: The pipeline standard, and a Floci fix built and tested

**Phase:** Phase 1 (delivery), standing goal (external validation)
**Related ADRs:** [ADR-0024](../../adr/0024-ci-cd-pipeline-standard.md), [ADR-0023](../../adr/0023-build-and-delivery.md)

## What happened

**Pipeline.** The owner asked for the pipeline to be researched against how GitHub Actions pipelines should be built,
fixed where it falls short, and written up as a template for future pipelines. The research
([`docs/research/2026-09-24-ci-cd-pipeline-research.md`](../research/2026-09-24-ci-cd-pipeline-research.md)) used GitHub's
hardening guide, OpenSSF Scorecard, SLSA, DORA, and the 2025 tj-actions and 2026 trivy-action compromises. Decisions in
ADR-0024; template in the [guide](../guides/ci-cd-pipeline-standard.md). Changes:

- **Pull requests no longer push images.** Before, a same-repository PR could push an image under a content tag that
  `main` would reuse without rebuilding: a path from unreviewed build changes to the cluster.
- `main` pushes by digest and records **SLSA provenance and a CycloneDX SBOM** as GitHub attestations; the bot now pins
  **`tag@digest`** (`bump-images.sh --verify` resolves digests; three new tests).
- The image build is one **reusable workflow**; the separate `bump-images.yml` (`workflow_run`, flagged high by zizmor) is
  replaced by a `pins` job at the end of `build` on `main`.
- **Trivy** pinned to v0.74.0 (the action's default v0.70.0 has a high advisory) and turned into a **ratchet**: fails on a
  fixable CRITICAL not accepted in `.trivyignore.yaml` (seven accepted, each with an expiry).
- **zizmor** and **kubeconform** added to `scripts/check`; an IaC misconfiguration scan in `infra`; `rescan.yml` (weekly scan
  of the deployed digests); `scorecard.yml`; **Dependabot** for actions, compose images and providers with a 7-day cooldown;
  `permissions: {}`, `persist-credentials: false` and timeouts everywhere.

**Floci fix.** Built and tested the CloudFront tag fix locally (see the upstream findings). Tests were written first and
failed on unchanged code for the bug's own reason. The first fix (store tags under the ARN) passed the service tests but not
the HTTP test: a second cause was found, the `?WithTags` flag arriving as null, so tags were never parsed. Fixed the same
way Floci's S3 controller reads its flags. Nothing has been sent upstream (the owner asked that nothing be opened until the
fix is proven).

**Environment.** Docker Desktop stopped mid-build (most likely memory: the cluster and a Java compile on 6.6 GB). The local
AWS was paused with `dev-down` (state backed up) for the Floci build, and comes back with `dev-up`.

## Verification

- `scripts/check`: all checks pass; zizmor 0 findings (from 1 high and 8 medium).
- Planted faults: kubeconform rejected a bad Deployment; zizmor flagged a script injection as high; the Trivy gate failed with
  no baseline and with an expired one. The first baseline (from older Security-tab data) missed a new critical
  (`CVE-2026-59873`); rebuilt from a fresh scan of all 12 images with Trivy v0.74.0, after which all 12 pass.
- Not yet verified: the workflows on GitHub (the first PR run proves them), attestation creation and `gh attestation verify`
  (first `main` build), the digest-pin bot PR (first `main` build).
- Floci: stock 2.1.0 and the 2026-09-24 nightly both fail 6 of 8 end-to-end checks (tags at creation lost, tags left behind
  after delete, OpenTofu drift). Results for the fixed build: see Next.

## Learn

- What makes a pipeline trustworthy, and the checklist for the next one ([guide](../guides/ci-cd-pipeline-standard.md)).
- A test that passes at one layer can hide a bug at another: the service-level tests passed while the HTTP path still lost
  the tags. Test at the layer users touch.
- A baseline is only as fresh as the scan it came from.

## Next

1. Finish the Floci verification: the regression suite, then a Floci image built from the fix, run against the same
   end-to-end checks; only then ask the owner about opening the upstream pull request.
2. Merge PR #26 once its checks (including the new workflows) pass; watch the first `main` build create attestations and the
   digest-pin PR.
3. Owner decisions: squash-only merges with linear history, Dependabot alerts and security updates, strict up-to-date checks.
4. `dev-up` to bring the local AWS back.
