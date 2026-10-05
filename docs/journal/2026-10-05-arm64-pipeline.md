# 2026-10-05: The arm64 pipeline, and the first publish and attestation

**Phase:** cross-cutting (the Mac era, step 4)
**Related ADRs:** [0027](../../adr/0027-arm64-only-app-images.md), [0025](../../adr/0025-tool-versions-and-tasks-in-mise.md) (Trivy part)

## What happened

- Images build on native arm runners with `BUILDPLATFORM` and `TARGETARCH` passed explicitly, content tags carry the architecture, and
  a new check (`.github/scripts/check-image-arch.sh`) proves the code inside an image is aarch64. Trivy runs as the locked binary in the
  build gate, the SBOM, the weekly rescan and the infrastructure scan; `trivy-action` is gone from the repository.
- Changing how images are built now rebuilds every service, so PR #38 built all 12 on arm runners before merging.
- Merged to `main`, which published all 12 images, attested them, and let the bot re-pin them.

## Why

The vendored Dockerfiles default their platform arguments to amd64 and the defaults win, so an arm64 build can silently produce an image
labelled arm64 that holds x86-64 code. The label proves nothing; the check looks at the code.

## Verification

*Verified on real GitHub Actions and on Floci:*

- The check **failed** a planted mislabelled image (`emailservice` built with the defaults: 114 of 114 files x86-64) and **passed** the
  real ones. In CI it printed the same counts as locally: 114, 1 and 29 aarch64 files.
- `main` published 12 images; each pinned digest reads `arm64/linux` in GHCR.
- **24 attestations verified** with `gh attestation verify` (12 SLSA provenance, 12 CycloneDX SBOM), each signed by
  `reusable-container-image.yml` of this repository, subject digests matching the pins. This was the first time publishing and
  attestation had ever run here.
- The bot's pin PR (#39) auto-merged, Argo CD rolled out the arm64 images, and all 11 pods run with 0 restarts. Before, five failed
  (four crash-looping, one OOM-killed). `online-boutique-dev` is Synced and Healthy; the shop's home, product and cart pages return 200.

## Mistakes and what they taught

1. **I replaced `trivy-action` in two workflows and missed the third** (the infrastructure scan in `infra.yml`), which would have left two
   Trivy versions. Found by grepping for the thing I thought I had removed. Search for a thing before claiming it is gone.
2. **My first registry query was wrong, not the images.** It reported "not arm64" for all 12 because it assumed an image index; these are
   plain manifests. When every result is identical, suspect the query. I inspected one by hand before concluding.
3. **`gh attestation verify` prints nothing on success when not in a terminal.** My filter saw blank output and could have been read as
   either result. Exit codes plus `--format json` gave real evidence (predicate type, signer workflow, subject digest).

## Learn

- A platform label is a claim; the code is the evidence. Check the contents (see the check's design: it reads files and never runs
  the image, so it works for images with no shell).
- Provenance says *which workflow built this digest*; an SBOM says *what is in it*. Both are verified against the digest, not the tag.
- A pipeline change should be tried on images in its own pull request, which is why the rebuild trigger now includes the build scripts.

## Next

The ECR module deleted and a lean `up` with an opt-in `extras` root (ADR-0022 amendment); then Phase 1 close-out: the pre-merge deploy
check, the guardrails for agent pull requests, and the threat model. The shop works now, which makes the scenario library possible.
