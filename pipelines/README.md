# /pipelines

The Phase 2 "golden path": the build job in `.github/workflows/build.yml` (change detection, a
per-service matrix, cached build, scan, push) extracted into a reusable `workflow_call` workflow
with per-service configuration, so a new service needs configuration rather than a new pipeline.

Phase 1 already replaced the per-service pipelines with one matrix workflow
([ADR-0007](../adr/0007-ci-split-ghcr-and-floci-scope.md)); the golden path makes that reusable and
owned by the platform team. Concrete workflows live under `.github/workflows`; shared or callable
definitions and composite actions come here when Phase 2 starts.
