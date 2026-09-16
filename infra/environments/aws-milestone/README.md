# environments/aws-milestone

Real-AWS validation environment (ADR-0002/ADR-0003): reuses the same `../../modules/vpc` (and
future `eks-cluster`/`ecr`/`iam` modules) this project builds against Floci, pointed at real AWS
instead of a local endpoint.

Not built yet. When Phase 1 reaches its milestone validation step, this gets:

- A `provider "aws"` block using GitHub Actions OIDC federation (no static credentials), not the
  `test`/`test` keys used against Floci.
- The AWS Budgets + billing alarm module, applied before anything else here ever runs.
- The same module calls as `environments/floci/main.tf`, so the only thing that changes between
  environments is the provider block and any environment-specific variables — not the
  infrastructure shape itself.

Spun up briefly for validation, torn down immediately after (ADR-0002).
