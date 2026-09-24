# 2026-09-16: First Terraform module — VPC, against the Floci environment

**Phase:** Phase 1 — AWS IaC + GitHub Actions foundation
**Related ADRs:** [ADR-0002](../../adr/archive/0002-aws-emulation-strategy.md), [ADR-0003](../../adr/archive/0003-eks-ephemeral-vs-ecs-fargate.md)

## What happened

Built the first real infra piece: `infra/modules/vpc` (VPC, public/private subnets across 2
AZs, an internet gateway, one shared NAT gateway) and `infra/environments/floci` (root config
that instantiates the module with the AWS provider pointed at `http://localhost:4566`, dummy
`test`/`test` credentials, and the skip-validation flags Floci needs). Also stubbed
`infra/environments/aws-milestone` as a README-only placeholder describing what it becomes at
the real-AWS milestone step (OIDC provider block, budgets module applied first).

Chose a single shared NAT gateway over one-per-AZ: cheaper and simpler, and this project's
environments are either free (Floci) or short-lived (milestone runs), so the HA argument for
per-AZ NAT doesn't apply. Exposed as a variable (`single_nat_gateway`) rather than hardcoded, in
case that judgment call needs revisiting later without a rewrite.

## Why

Environments intentionally share one module tree so what gets validated against real AWS at
milestone time is the same Terraform shape exercised daily against Floci (ADR-0002's whole
point), not a parallel definition that could silently drift.

## Verification

- `terraform fmt -check -recursive` run in a sandbox with a manually-downloaded Terraform
  binary (the sandbox's egress proxy blocks `registry.terraform.io`, so the AWS provider itself
  couldn't be pulled there). Caught and fixed one formatting issue.
- `terraform init` / `plan` / `apply` against the real running Floci instance still need to be
  run by the user — not yet confirmed as of this entry. Follow-up journal entry once that comes
  back clean (or once something needs fixing).

## Next

Pending: user runs `terraform init && terraform plan && terraform apply` in
`infra/environments/floci` and reports back. Once clean, next module is the EKS-equivalent
cluster (ADR-0003), then ECR, then IAM.
