# 2026-09-20: EKS-equivalent cluster module, wired into the Floci environment

**Phase:** Phase 1 — AWS IaC + GitHub Actions foundation
**Related ADRs:** [ADR-0003](../../adr/0003-eks-ephemeral-vs-ecs-fargate.md), [ADR-0002](../../adr/0002-aws-emulation-strategy.md)

## What happened

Added `infra/modules/eks-cluster`: an EKS control plane, a managed node group (default
`t3.medium`, 1-3 nodes, desired 2), and the two IAM roles they need (cluster role, node role,
with the standard AWS-managed policy attachments). Instantiated it in `environments/floci` on
the VPC module's private subnets, with `cluster_name`/`cluster_endpoint` outputs.

The IAM roles live inside this module for now rather than waiting for the separate IAM module
on the roadmap: EKS can't be created without them, and the IAM module's scope (OIDC federation
for GitHub Actions, later IRSA) is different. Revisit if the roles need to be shared.

## Why

ADR-0003 already covers the EKS-over-Fargate decision; nothing new needed an ADR.

## Verification

`tofu fmt -recursive`, `tofu validate` ("configuration is valid"), and `tofu plan` against the
live Floci instance: `Plan: 8 to add, 0 to change, 0 to destroy` (2 IAM roles, 4 policy
attachments, cluster, node group). Not yet applied — `tofu apply` is left to the user.

## Next

- User runs `tofu apply` in `infra/environments/floci`; watch for Floci gaps in node group
  support (k3s-backed) and record any as findings.
- Then the ECR-equivalent registry module, then IAM.
