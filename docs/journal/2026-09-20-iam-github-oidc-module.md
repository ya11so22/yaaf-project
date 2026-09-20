# 2026-09-20: IAM module — GitHub OIDC provider and three roles

**Phase:** Phase 1 — AWS IaC + GitHub Actions foundation
**Related ADRs:** [ADR-0006](../../adr/0006-github-oidc-role-design.md)

## What happened

Probed Floci's IAM first, then wrote ADR-0006 (three roles, chosen by the user over one or two)
and `infra/modules/github-oidc`: the GitHub OIDC provider (optional, one per account) and
three roles — `ecr-push`, `tofu-plan` (ReadOnlyAccess), `tofu-apply` (EC2/EKS/ECR plus IAM
role management restricted to the project prefix). Trust uses exact-match `StringEquals` on
`aud` and `sub`: plan from `pull_request`, apply only from `refs/heads/main`, ecr-push from
both. Wired into `environments/floci`, taking the ECR repository ARNs from the ecr module.

## Finding: Floci does not enforce trust policies

Floci accepts OIDC providers, roles with web-identity trust, and inline policies, and returns
the conditions unchanged. But `sts assume-role-with-web-identity` returned credentials for an
unsigned token with a matching subject **and** for one claiming `repo:someone-else/evil`.
Neither the `sub` condition nor the signature is checked. So on Floci this module can only be
verified for shape; the security property must be tested on real AWS at the milestone, including
a negative test that a foreign repository is refused. Recorded in ADR-0006; a Phase 2 policy
check (`conftest` on the plan) should also forbid wildcard `sub` values.

## Verification

`tofu fmt`, `tofu validate` (valid), `tofu plan` against live Floci: `Plan: 7 to add, 0 to
change, 0 to destroy`. Not yet applied. Probe roles and the probe provider were deleted.
A probe note: the Windows AWS CLI can't read Git Bash `/tmp` paths in `file://` arguments.

## Next

- User runs `tofu apply`; then check the resources exist and the trust document round-trips.
- Phase 1 GitHub Actions work (path-filtered builds, plan on PR, apply on merge), which will
  consume these roles on real AWS. Also still to do: budgets/billing alarm before anything
  touches real AWS.
