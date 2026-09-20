# 2026-09-20: Terraform installed locally, VPC plan validated, state backend strategy decided

**Phase:** Phase 1 — AWS IaC + GitHub Actions foundation
**Related ADRs:** [ADR-0002](../../adr/0002-aws-emulation-strategy.md), [ADR-0004](../../adr/0004-tfstate-backend-strategy.md)

## What happened

Picked up from the prior session's handoff, on the user's local machine (Windows, PowerShell)
rather than the cloud sandbox that scaffolded the VPC module.

1. Confirmed Floci was already running and healthy locally (`floci` + `floci-ui` containers up,
   `/_floci/health` returning all services `running`).
2. Terraform wasn't installed on this machine yet. Installed it via `winget install
   Hashicorp.Terraform` (v1.16.2) with the user's explicit sign-off on that install method.
3. Ran `terraform init` in `infra/environments/floci` — succeeded, pulled `hashicorp/aws
   v5.100.0`, created `.terraform.lock.hcl`.
4. Ran `terraform plan -out=tfplan` — 14 resources to create (VPC, 2 public + 2 private
   subnets, IGW, 1 NAT gateway + EIP, 2 route tables, 4 route table associations), 0 to
   change/destroy. Matches the module design from the prior VPC-module journal entry.
5. `terraform apply` itself was left to the user to run by hand (their preference, and also
   blocked by the local auto-mode classifier as a "blind apply" — a live infra-mutating command
   run from a saved plan file).
6. Found and fixed two `.gitignore` gaps while reviewing pre-apply hygiene:
   - `*.tfplan` didn't match `terraform plan -out=tfplan`'s actual output filename (bare
     `tfplan`, no extension) — the plan file was showing up as untracked. Added an explicit
     `tfplan` entry.
   - `.terraform.lock.hcl` was being ignored via `**/.terraform.lock.hcl`, contrary to
     Terraform's own guidance to commit that file for reproducible provider versions across
     machines/CI. Removed the ignore rule.
7. Worked through the Terraform state backend question the user raised before applying:
   evaluated HCP Terraform (free tier) for everything, local-only for everything, and a split
   strategy — landed on splitting by environment because HCP Terraform's free-tier "remote"
   execution runs on HashiCorp's cloud runners, which can reach real AWS but can't reach
   `localhost:4566` (Floci). Wrote this up as [ADR-0004](../../adr/0004-tfstate-backend-strategy.md)
   rather than letting it live only in chat/journal, since it's an architectural decision, not
   just a config default.
8. Also discussed self-hosted state backend options (MinIO + Terraform's native S3 state
   locking, or the `pg` backend) as a considered-but-not-needed-yet alternative; logged as a
   Phase 2 stretch candidate in `docs/milestones.md` rather than acting on it, since neither
   current environment needs state to outlive a single job/session.

## Why

See ADR-0004 for the backend decision's own rationale. The `.gitignore` fixes were caught
opportunistically while reviewing what an `apply` would leave behind on disk, not part of the
original plan for the session.

## Verification

```
terraform version                     # v1.16.2
terraform init                        # "Terraform has been successfully initialized!"
terraform plan -out=tfplan            # Plan: 14 to add, 0 to change, 0 to destroy.
git status --short                    # confirms tfplan now ignored, .terraform.lock.hcl now trackable
```

`terraform apply tfplan` itself is still pending — left for the user to run locally and confirm
back (see prior journal entry's same open item, now just one command away).

## Next

- User runs `terraform apply tfplan` in `infra/environments/floci`, confirms `terraform output`
  shows populated `vpc_id`/`public_subnet_ids`/`private_subnet_ids`.
- Commit the `.gitignore` fix, the new `.terraform.lock.hcl`, and ADR-0004.
- Set up the HCP Terraform (free tier) workspace for `environments/aws-milestone` per ADR-0004,
  scoped to that working directory.
- Next Terraform module: EKS-equivalent cluster (ADR-0003).
