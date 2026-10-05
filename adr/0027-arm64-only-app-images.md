# ADR-0027: The app images are arm64 only

**Status:** accepted (refines [ADR-0023](0023-build-and-delivery.md) item 1 and [ADR-0024](0024-ci-cd-pipeline-standard.md))
**Date:** 2026-10-03
**Evidence:** *tested* on the owner's Mac (Apple M2, `buildx` 0.37.2, a dedicated Colima VM); the CI change is designed.

## Context

The development machine, its container VM, Floci and the k3s node are arm64. The twelve app images are built for
`linux/amd64` only (`platforms: linux/amd64` in `reusable-container-image.yml`), so on the Mac they run under
emulation or fail with `exec format error`. The first draft of this decision assumed a native arm64 builder would build
the Dockerfiles unchanged. **That was wrong, and testing showed why:** every Dockerfile declares
`ARG BUILDPLATFORM=linux/amd64` (the Go and .NET ones also `ARG TARGETARCH=amd64`) as a "default in case the builder
provides none", and those defaults win over the real values. With `buildx build --platform linux/arm64` on the arm64 VM:

| Service kind | Default arguments | With `--build-arg BUILDPLATFORM=linux/arm64 --build-arg TARGETARCH=arm64` |
|---|---|---|
| Java (`adservice`), Node (`currencyservice`) | built; running the image reports `aarch64` | not needed |
| Python (`emailservice`, `loadgenerator`, `recommendationservice`, `shoppingassistantservice`) | built and **labelled arm64, but Python inside reports `x86_64`**: a silently wrong image (all four) | Python reports `aarch64` (all four) |
| Go (`checkoutservice`, `frontend`, `productcatalogservice`, `shippingservice`) | **failed**: the amd64 Go toolchain crashed under Rosetta (`fatal error: found pointer to free object`, `fault`, and similar) | built; for `productcatalogservice` the binary in the image is `ELF 64-bit ... ARM aarch64` |
| .NET (`cartservice`) | **failed**: `dotnet restore -a amd64` errored | built; the binary in the image is `ELF 64-bit ... ARM aarch64` |

`paymentservice` (Node) also built with the defaults; its contents were not inspected. The Java and Node images tested were
unaffected; for `currencyservice` the reason is visible in its Dockerfile, where the final stage is a separate
`FROM alpine` and does not inherit from the build-platform stage.

## Options considered

1. **Stay amd64.** Rosetta on the Mac for good; slow, and some JVM and .NET workloads break under emulation.
2. **Multi-arch (amd64 and arm64) merged into one index.** Needs both runners, an `imagetools` merge, and an answer to
   which digest to attest; GitHub's documentation does not say. Worth it only if something must run on amd64, and
   nothing in the roadmap does.
3. **arm64 only, on native arm runners, with explicit build arguments** (chosen).
4. **Edit the Dockerfiles to remove the defaults.** Fixes the cause but changes Google's vendored code and needs a
   modification notice on twelve files (Apache-2.0); the build arguments do the same without touching `app/`.

## Decision

1. **Images are built for `linux/arm64` only**, on the `ubuntu-24.04-arm` runner, with
   `build-args: BUILDPLATFORM=linux/arm64` and `TARGETARCH=arm64`. One digest is attested (provenance and SBOM
   unchanged). No `imagetools` merge.
2. **A check proves the architecture of what is inside**, not the label, and fails the build unless it is `aarch64`.
   Images with a shell (the Python and Node ones) are asked directly (`python -c "import platform;
   print(platform.machine())"`, `uname -m`). Distroless and chiseled images (Go, .NET) have no shell, so the check
   exports the image's filesystem (`docker create`, then `docker export`) and runs `file` on its entrypoint binary,
   which printed `ARM aarch64` for the two images tried. A mislabelled image must not be able to ship. (This is also
   scenario material, ADR-0028.) **Built as `.github/scripts/check-image-arch.sh`** (2026-10-05): it exports the image's files
   (it never runs the image, so it needs no shell), requires every ELF executable and shared library to be aarch64, and
   requires at least one ELF so an empty export cannot pass. *Proven on real images:* `emailservice` built with the vendored
   defaults (labelled arm64) failed with 114 of 114 files x86-64; the same service with the explicit arguments passed with 114
   aarch64; the distroless Go image (1 ELF file) and the chiseled .NET image (29) passed. Its unit tests use hand-made ELF headers
   and run in `check`, with no Docker.
3. **Every job that runs this project's containers uses an arm runner**: the image build and the pre-merge deploy
   check. Jobs that run no project images stay on `ubuntu-latest`.
4. **The Rosetta setting in the `yaaf` VM is a bridge**, kept only until the first arm64 images are deployed.
5. The Dockerfiles' defaults stay as upstream wrote them.
6. **Content tags carry the architecture** (`content-<hash>-arm64`). The build skips a service whose content tag already
   exists on GHCR (ADR-0023), and the existing amd64 images carry the plain `content-<hash>` tags, so without this the
   first arm64 build would find them and reuse an amd64 image. The suffix also keeps the tag honest if a second
   architecture is ever added. `content-tag.sh` and its tests change with it.

## Rationale

arm64 end to end removes emulation, matches AWS Graviton (relevant to the cost model in the architecture track), and
GitHub's arm runners (`ubuntu-24.04-arm`) are free and generally available for public repositories
([changelog, August 2025](https://github.blog/changelog/2025-08-07-arm64-hosted-runners-for-public-repositories-are-now-generally-available/)),
and this repository is public; they do not work in private ones. Verifying the content, not the
label, is the lesson of the test above.

## Consequences / trade-offs accepted

- The images do not run on an amd64 machine. If that is ever needed, add `linux/amd64` back as a second build and
  solve the attestation question then.
- Existing pins in `deploy/dev` point at amd64 digests until the first arm64 build lands. Because the tag now differs,
  that first `main` build publishes all twelve services and the bot re-pins them in one pull request. The old amd64
  images age out through the GHCR cleanup (newest 10 versions per service).
- Acceptance: all twelve services build on the arm runner; the architecture check fails on a planted amd64 image;
  `gh attestation verify` passes for one published digest (the first real exercise of publishing and attestations,
  HANDOFF item 2).
