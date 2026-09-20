# 2026-09-20: Path-filtered per-service builds (build.yml)

> **Superseded 2026-09-20 by [ADR-0007](../../adr/0007-ci-split-ghcr-and-floci-scope.md):** the
> per-job Floci/`tofu` registry described here was replaced by GHCR. The change-detection
> script survives.

**Phase:** Phase 1 — AWS IaC + GitHub Actions foundation
**Related ADRs:** [ADR-0002](../../adr/0002-aws-emulation-strategy.md), [ADR-0006](../../adr/0006-github-oidc-role-design.md)

## What happened

Added `.github/workflows/build.yml` and `.github/scripts/changed-services.sh`. The workflow has
two jobs: `changes` works out which services need building, and `build` runs one matrix job per
service. Design choice (the user picked it over 12 near-identical workflow files): a single
workflow with a changed-service matrix; Phase 2 extracts the build job into a reusable
`workflow_call` (the "golden path").

Details:

- The script diffs base..head and maps `app/src/<service>/**` to services. It builds all 12 when
  the base is empty, all zeros (new branch) or unknown (force push), or when the workflow or
  script itself changed. It maps `cartservice` to `app/src/cartservice/src`, the only service
  whose Dockerfile is not at the service root. JSON is assembled in plain bash because `jq`
  is not assumed locally.
- Each build job starts Floci from the same `compose.yaml` used locally (one source of truth
  for its config), creates the registry with `tofu apply -target=module.ecr` so the real module
  (immutable tags, scanning) is exercised, builds, pushes `<sha>` to the repository URL taken
  from the `ecr_repository_urls` output (never hard-coded, since URLs differ on real AWS), and
  verifies the tag is listed.
- Images go to a throwaway Floci registry per ADR-0002; real ECR is for the AWS milestone.
- `permissions: contents: read`, concurrency cancels superseded runs, and both third-party
  actions are pinned to commit SHAs (checkout v7.0.1, setup-opentofu v2.0.2).

## Verification

- Script: 12 services for a new-branch base; `cartservice` gets the `src` context; a docs-only
  diff gives `[]`; a simulated `frontend` change gives only `frontend`.
- `actionlint` (which runs shellcheck on the run blocks): clean after one fix (unused loop var).
- Dry run of the build/push/verify commands for `emailservice` against the local Floci:
  built, pushed, tag listed, then deleted.
- **Not yet verified:** an actual GitHub run. The workflow only triggers on pull requests and on
  pushes to `main` that touch `app/src/**` or the workflow files, so it needs a PR to run.
  Untested on a runner: Floci start via compose, `tofu` setup, and the heavier Dockerfiles
  (adservice/Gradle, cartservice/.NET).

## Next

- Open a PR to get the first real run (the workflow file change builds all 12), fix whatever
  the runner shows.
- Then `tofu plan` on PR with the plan as a comment, and `tofu apply` on merge.
