# 2026-09-20: ECR-equivalent registry module, wired into the Floci environment

**Phase:** Phase 1 — AWS IaC + GitHub Actions foundation
**Related ADRs:** [ADR-0002](../../adr/archive/0002-aws-emulation-strategy.md)

## What happened

Added `infra/modules/ecr`: one repository per service (`<prefix>/<service>`) plus a lifecycle
policy on each, and instantiated it in `environments/floci`. Settings, all overridable:

- `image_tag_mutability = IMMUTABLE` so a deployed tag always means the same image (CI will push
  per-commit tags). Anything needing a moving tag like `latest` would have to opt into MUTABLE.
- `scan_on_push = true`, AES256 encryption.
- Lifecycle: keep the 10 most recent images, expire the rest.
- `force_delete = true` in the Floci environment only, so `tofu destroy` works with images
  present; the module default is false.

Before writing it, probed Floci with the AWS CLI: `create-repository` with scan-on-push and
immutable tags, and `put-lifecycle-policy`, all work and round-trip. Repository URIs come back
as `000000000000.dkr.ecr.us-east-1.localhost:4566/<name>`.

## Discrepancy to resolve

`app/src` has **12** service directories, not the 11 the brief and milestones mention: the extra
one is `shoppingassistantservice`. The environment creates a repository for all 12 (a repo per
directory is cheap); whether the pipeline should build the twelfth is still open. `loadgenerator`
is a test tool rather than a runtime service, but is also included.

## Why

No new decision needing an ADR; the mutability/scan/lifecycle defaults are recorded above.

## Verification

`tofu fmt -recursive`, `tofu validate` (valid), and `tofu plan` against live Floci:
`Plan: 24 to add, 0 to change, 0 to destroy` (12 repositories, 12 lifecycle policies). Applied by the user afterwards (see below).

## Applied, and image push verified (2026-09-20)

`tofu apply` created all 12 repositories; `tofu plan` showed no drift. Pushing an image is a
separate check from creating repos, and it failed at first: Floci's default repository URI is
`<account>.dkr.ecr.<region>.localhost:4566/<repo>`, which relies on `*.localhost` subdomains
resolving to loopback (RFC 6761). On this Windows machine they don't: Windows' resolver
(`No such host is known`) and Docker Desktop's DNS (`NXDOMAIN`) both refuse them, so
`docker login`/`push` failed with `no such host`.

Resolution: set `FLOCI_SERVICES_ECR_URI_STYLE=path` in `compose.yaml`, which makes URIs
`localhost:4566/<account>/<region>/<repo>`. Floci's docs describe this as a fallback for
platforms where `*.localhost` misbehaves, so I checked it is actually wired through rather than
assuming: Floci's k3s containerd mirror config (`registries.yaml`) contains both the 15
hostname-style names and a plain `localhost:4566` entry.

Verified end to end:
- `docker login` + `docker push` of a busybox image to `yaaf/adservice:test1` succeeded, and
  `aws ecr list-images` shows the tag (so the ECR API and backing registry agree).
- Pushing a different image to the same tag was rejected ("tag is immutable"), confirming
  `IMMUTABLE` is enforced.
- In-cluster: pods referencing the image by both the hostname-style and the path-style name
  pulled and ran (`kubectl run` inside the cluster container).
- Test pods and the test image were deleted afterwards.

Consequences:
- Repository URLs differ per environment (`localhost:4566/<account>/<region>/<repo>` on Floci,
  `<account>.dkr.ecr.<region>.amazonaws.com/<repo>` on real AWS). The pipeline must take URLs
  from the `ecr_repository_urls` output, never hard-code them. Only that output changed in
  `tofu plan`; no resources.
- Known upstream bug (floci #1134): Lambda image invocation ignores path style. Not relevant
  here (no Lambda), but worth knowing.
- Each Floci restart leaves another `NotReady` ghost node (see the EKS entry); deleted again.

## Next

- IAM module, then the GitHub Actions work.
