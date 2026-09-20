# 2026-09-20: Switched from Terraform to OpenTofu, VPC apply confirmed clean

**Phase:** Phase 1 — AWS IaC + GitHub Actions foundation
**Related ADRs:** [ADR-0005](../../adr/0005-opentofu-over-terraform.md)

## What happened

User ran `terraform apply tfplan` in `infra/environments/floci` — came back clean, VPC module's
14 resources created against Floci.

Right after, switched the whole project from Terraform to OpenTofu:

1. `winget uninstall Hashicorp.Terraform`, `winget install OpenTofu.Tofu` (v1.12.6).
2. Removed the stale `.terraform/`, `.terraform.lock.hcl`, and now-applied `tfplan` in
   `infra/environments/floci`; re-ran `tofu init` (resolved the same `hashicorp/aws v5.100.0`)
   and `tofu plan` — "No changes. Your infrastructure matches the configuration.", confirming
   OpenTofu reads the Terraform-applied state with zero drift.
3. Updated forward-looking references from `terraform`/"Terraform" to `tofu`/"OpenTofu" in
   `README.md`, `infra/README.md`, `CONTRIBUTING.md`, and the unchecked items in
   `docs/milestones.md`. Left historical journal/ADR entries as-written.
4. Wrote [ADR-0005](../../adr/0005-opentofu-over-terraform.md) for the switch itself.
5. Flagged, in `docs/milestones.md`, that ADR-0004's choice of HCP Terraform for
   `environments/aws-milestone` is now in tension with OpenTofu (HCP Terraform's remote
   execution doesn't run OpenTofu) — logged as an open follow-up rather than resolved now,
   since that environment doesn't exist yet.

## Why

See ADR-0005.

## Verification

```
tofu version                          # OpenTofu v1.12.6
Get-Command terraform                 # not found (uninstalled)
tofu init                             # resolved hashicorp/aws v5.100.0, same as under Terraform
tofu plan                             # No changes. Your infrastructure matches the configuration.
```

## Next

- Pick a backend for `environments/aws-milestone` when that environment actually gets built
  (open follow-up in `docs/milestones.md`) — don't decide it speculatively now.
- Next OpenTofu module: EKS-equivalent cluster (ADR-0003).
