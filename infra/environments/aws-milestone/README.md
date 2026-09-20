# environments/aws-milestone

The `milestone` environment: real AWS, used briefly to validate what Floci cannot, then torn down
([ADR-0002](../../../adr/0002-aws-emulation-strategy.md), [ADR-0003](../../../adr/0003-eks-ephemeral-vs-ecs-fargate.md),
[ADR-0008](../../../adr/0008-phase-reslice-cd-and-team-model.md)). It reuses the modules built and
tested against Floci, so only the provider block and environment variables differ.

Not built yet. When Phase 1 reaches this step it gets, in this order:

1. **AWS Budgets + billing alarm**, applied before anything else here runs.
2. **A `provider "aws"` block without static credentials.** GitHub Actions federates in through
   the OIDC provider and roles from `modules/github-oidc` (ADR-0006).
3. **The same module calls as `environments/floci`** (`vpc`, `eks-cluster`, and the OIDC module,
   with `ecr` only if the milestone needs it, since images live on GHCR).
4. **A state backend.** Unresolved: ADR-0004 chose HCP Terraform, but that cannot run OpenTofu, so
   pick an OpenTofu-compatible option first (see `docs/milestones.md`).

It is deployed only by a manual dispatch behind a GitHub Environment approval, taking an image
digest as input (the one proven in `dev`), and torn down afterwards.

This is also where the security properties Floci cannot prove get tested, including a negative
test that a foreign repository cannot assume the OIDC roles.
