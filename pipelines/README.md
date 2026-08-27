# /pipelines

Reusable/callable GitHub Actions workflows — the Phase 2 "golden path" pattern that collapses
the 11 near-identical per-service pipelines (one per Online Boutique service) into a single
parameterized, callable workflow.

Concrete per-service workflow files live under `.github/workflows`; shared/callable workflow
definitions and any composite actions live here once Phase 2 starts.
