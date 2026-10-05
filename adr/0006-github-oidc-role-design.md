# ADR-0006: GitHub Actions federates into AWS via OIDC with three least-privilege roles

**Status:** accepted (2026-09-24; the negative trust test moves to the zero-spend lane, [ADR-0020](0020-zero-spend-real-aws-lane.md), which also adds the permissions boundary this ADR anticipated; ADR-0020 was rejected on 2026-10-03 and the trust test is now the overbroad-trust scenario of [ADR-0028](0028-scenario-library.md))
**Date:** 2026-09-20

## Context

The pipeline needs AWS access from GitHub Actions with no long-lived credentials (Phase 1
brief). That means an IAM OIDC identity provider for `token.actions.githubusercontent.com` and
roles GitHub workflows assume with `sts:AssumeRoleWithWebIdentity`. The open design question is
how many roles, and who may assume each.

Three different workflows need three different powers:

- **Build**: push images to the 12 ECR repositories (runs on PRs and on main).
- **Plan**: `tofu plan` on every pull request. Only needs to read.
- **Apply**: `tofu apply` on merge. Needs to create and change infrastructure.

Fidelity constraint found while probing (2026-09-20): Floci's IAM stores OIDC providers, roles
and trust conditions faithfully, but its `AssumeRoleWithWebIdentity` issues credentials to
*any* token, including one whose `sub` names a different repository, and does not verify the JWT
signature. The trust conditions that make this design secure therefore cannot be proven against
Floci.

## Options considered

1. **One CI role for everything, trusted for the whole repo.**
   - Pros: least code.
   - Cons: a pull request (including anything that can run workflow code) gets write access
     to infrastructure. Weakest story.
2. **Two roles: ECR push, and one tofu role for both plan and apply.**
   - Pros: simpler.
   - Cons: PR-triggered plan runs still get write access.
3. **Three roles: `ecr-push`, `tofu-plan` (read-only), `tofu-apply` (write).**
   - Pros: trust is tied to the workflow's `sub` claim: plan is assumable from
     `pull_request`, apply only from `refs/heads/main`, so a PR can never apply. Each policy is
     as small as its job allows.
   - Cons: more resources; the apply role is still powerful (see below).

## Decision

Option 3. Trust policies use exact-match `StringEquals` on the `sub` claim (no wildcards) plus
`aud = sts.amazonaws.com`:

| Role | May be assumed from | Permissions |
|---|---|---|
| `ecr-push` | `pull_request`, `refs/heads/main` | ECR push/pull on the 12 repositories only, plus `GetAuthorizationToken` |
| `tofu-plan` | `pull_request` | `ReadOnlyAccess` |
| `tofu-apply` | `refs/heads/main` | EC2, EKS and ECR, plus IAM role management limited to names under the project prefix |

The OIDC provider is optional in the module (`create_oidc_provider`) because AWS allows only
one per URL per account.

## Rationale

The `sub` claim is the only thing that distinguishes a PR run from a merge run, so the role
split has to follow it. Making the apply role assumable only from `main` means the merge gate
(review, checks) is also the permission gate.

## Consequences / trade-offs accepted

- **The apply role can create IAM roles** under the prefix and attach policies to them, so it is
  effectively able to escalate within that prefix. Accepted because the AWS environment is
  temporary and budget-capped (ADR-0002/0003), and the role is main-only. Revisit with a
  permissions boundary if a long-lived account is ever used.
- **Trust is not testable on Floci.** The Floci run proves the module's shape (resources,
  policies, conditions round-trip). Whether a foreign repository is actually refused must be
  verified at the real-AWS milestone, with an explicit negative test. A Phase 2 policy-as-code
  check (`conftest` on the plan) should also assert that no role trusts a wildcard `sub`.
- The plan role needs access to wherever state lives; that is unresolved (ADR-0004 follow-up
  on the `aws-milestone` backend) and is not granted here.

## Amendment 2026-10-05: two roles, not three

The ECR module was deleted ([ADR-0022](0022-the-local-aws-environment.md) amendment): nothing used it, and CI pushes to GHCR. The
`ecr-push` role existed only to push to those repositories, so it goes with them (a role with no resources to grant is not valid
policy). `ecr:*` also leaves the `tofu-apply` role's infrastructure permissions. What remains:

| Role | May be assumed from | Permissions |
|---|---|---|
| `tofu-plan` | `pull_request` | `ReadOnlyAccess` |
| `tofu-apply` | `refs/heads/main` | EC2 and EKS, plus IAM role management limited to names under the project prefix |

Trust is unchanged: exact-match `StringEquals` on `sub`, no wildcards, plus `aud = sts.amazonaws.com`. The overbroad-trust scenario of
[ADR-0028](0028-scenario-library.md) still uses the `tofu-apply` role.

