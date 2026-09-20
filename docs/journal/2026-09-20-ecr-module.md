# 2026-09-20: ECR-equivalent registry module, wired into the Floci environment

**Phase:** Phase 1 — AWS IaC + GitHub Actions foundation
**Related ADRs:** [ADR-0002](../../adr/0002-aws-emulation-strategy.md)

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
`Plan: 24 to add, 0 to change, 0 to destroy` (12 repositories, 12 lifecycle policies). Not yet
applied — `tofu apply` is left to the user.

## Next

- User runs `tofu apply`; then push a test image to confirm the registry actually accepts it
  (`docker push` to the Floci registry endpoint), since creating repos doesn't prove that.
- IAM module, then the GitHub Actions work.
