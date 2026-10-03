# ADR-0005: OpenTofu over Terraform as the IaC CLI

**Status:** accepted (2026-09-24; the state-backend follow-up is settled by [ADR-0022](0022-the-local-aws-environment.md): S3 on Floci)
**Date:** 2026-09-20

## Context

All infra work so far (`infra/modules/vpc`, `infra/environments/floci`) was built and first
applied using HashiCorp's Terraform CLI. Before more modules get built on top of it, switched
to OpenTofu (the Linux Foundation-governed, community-maintained fork) as the IaC tool for the
rest of the project.

## Options considered

1. **Keep Terraform.**
   - Pros: no migration step, what's already applied stays untouched.
   - Cons: none specific to this project beyond preference — the switch is being made now,
     before more modules are built on top of it, precisely to avoid a larger migration later.
2. **Switch to OpenTofu.**
   - Pros: community-governed continuation of the pre-fork open-source project; CLI is
     drop-in compatible (same HCL, same `terraform {}` block name, same provider ecosystem);
     switching now, with only one module built, is the cheapest point in the project to do it.
   - Cons: one-time migration step (reinstall CLI, re-`init` existing environments).

## Decision

Switched to OpenTofu (`tofu` CLI, v1.12.6) as the IaC tool for this project, replacing
Terraform system-wide and in the repo. Preference for the community-governed fork, independent
of any specific license grievance.

## Rationale

The switch was made at the lowest-cost point possible — one module built, one environment
applied — rather than accumulating more Terraform-specific tooling first. OpenTofu's CLI
compatibility made the migration mechanical: existing state (already applied against Floci)
was read cleanly with no drift (`tofu plan` → "No changes"), same provider version resolved
(`hashicorp/aws v5.100.0`), no HCL changes needed anywhere in the repo.

## Consequences / trade-offs accepted

- All commands going forward use `tofu`, not `terraform` — READMEs and milestones updated
  accordingly; historical journal/ADR entries written before this date still say "Terraform"
  and are left as-is (accurate record of what was true at the time).
- ADR-0004's choice of HCP Terraform for `environments/aws-milestone` is now in tension with
  this decision: HCP Terraform's remote execution runs HashiCorp's own Terraform binary, not
  OpenTofu. That environment isn't built yet, so this is tracked as an open follow-up (see
  `docs/milestones.md`) rather than resolved speculatively here — the right backend gets picked
  when `aws-milestone` actually gets built.
- `.terraform.lock.hcl` was regenerated under OpenTofu (same provider version, new lock file)
  rather than hand-edited, since OpenTofu recommends a fresh `init` over reusing a
  Terraform-generated lock file.
