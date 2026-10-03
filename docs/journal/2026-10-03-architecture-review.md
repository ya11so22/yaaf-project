# 2026-10-03: Fresh-eyes architecture review and the Mac-era decisions

**Phase:** cross-cutting
**Related ADRs:** [0025](../../adr/0025-tool-versions-and-tasks-in-mise.md), [0026](../../adr/0026-argo-cd-app-of-apps.md), [0027](../../adr/0027-arm64-only-app-images.md), [0028](../../adr/0028-scenario-library.md), [0029](../../adr/0029-gateway-api-for-ingress.md); amended 0009, 0021, 0022, 0023, 0024; 0020 rejected

## What happened

The owner asked for a fresh look at everything the handoff described, with permission to change or remove anything. A
multi-agent web review (104 agents, claims checked by three adversarial votes) plus a read of the repository produced
[the review](../research/2026-10-03-architecture-review.md). The owner then answered a structured list of questions, and
the answers became five new ADRs and amendments to six existing ones. Nothing was implemented.

Settled: one `mise.toml` and lockfile; Argo CD Applications in git; Gateway API; arm64-only images; a dedicated Colima VM;
a lean default `up`; the ECR module deleted and the OIDC roles kept; ADR-0020 rejected; the finish line without the
shopping-assistant replatform; and a library of failure scenarios written before they are run.

## Why

Version pins lived in several files that only memory kept in step; the platform half of GitOps was still HCL; the app was
amd64-only on an arm64 host; and the drills showed mechanisms rather than incidents. Each ADR records the options.

## Verification

Tested on this Mac: a dedicated Colima VM runs amd64 containers under Rosetta and passes the Docker socket through;
`docker-buildx` works in it; the twelve services were built as arm64. That test found that the Dockerfiles' hard-coded
`ARG BUILDPLATFORM=linux/amd64` defaults beat the real platform: Python images were labelled arm64 but held `x86_64`
Python, and Go and .NET builds failed; passing the real values fixed it (ADR-0027). The review's first claim that arm
runners would build the Dockerfiles unchanged was wrong and is corrected there. Release pages were read for current
versions (OpenTofu 1.13.1, Argo CD 3.5.3, Trivy 0.75.0 and others).

## Learn

- A platform label is not proof: check the architecture of what is *inside* an image.
- A default in a Dockerfile `ARG` can silently override the builder's real value.
- The Trivy action compromise (March 2026) is the reason to install security tools from a lockfile and pin actions by SHA.

## Next

Step 2 of the order in [`docs/milestones.md`](../milestones.md): `mise.toml`, the four tasks and `up` working end to end on
the Mac, which also answers whether Rosetta reaches pods inside Floci's cluster. Then app-of-apps with Gateway API and its
guide; then the arm64 pipeline. [`HANDOFF.md`](../../HANDOFF.md) is deleted once `up` works.
