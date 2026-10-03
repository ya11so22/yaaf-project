# Guide: IAM policies, boundaries and trust, and what the local AWS can prove

**Related:** [ADR-0006](../../adr/0006-github-oidc-role-design.md), [ADR-0020](../../adr/0020-zero-spend-real-aws-lane.md),
[`scripts/drills/iam-trust.sh`](../../scripts/drills/iam-trust.sh)
**Evidence:** verified on Floci (the drill, 2026-09-24). GitHub's own tokens: not verified on real AWS.

## The idea

IAM answers one question for every request: *may this caller do this action on this resource?* Three different
documents feed the answer, and mixing them up is the most common IAM mistake:

| Document | Attached to | Says | Analogy |
|---|---|---|---|
| **Identity policy** | A user or role | What it may do | A key ring |
| **Permissions boundary** | A user or role | The most it may *ever* do, whatever its policies say. The effective permission is the overlap | A limit written on the key ring |
| **Trust policy** | A role | *Who may become this role* | The list at the door of who may pick up the keys |

The rule underneath: an explicit **Deny** wins; otherwise you need an explicit **Allow**; otherwise it is denied.

**Trust** is what makes CI safe. GitHub Actions proves who it is with a signed token whose `sub` claim names the
repository and branch. A trust policy then says "only `repo:ya11so22/yaaf-project:ref:refs/heads/main` may assume this
role". Two things must both hold: the token's **signature** is checked against the issuer's public keys, and its
**claims** match the policy's conditions. A policy without a condition, or a wildcard `sub`, lets any repository in.

## How it works here

The drill [`scripts/drills/iam-trust.sh`](../../scripts/drills/iam-trust.sh) runs everything below and cleans up after itself.
Floci has an **enforcement mode** (`FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true`) that is off by default, so the drill
starts a throwaway Floci with it on, beside your environment.

| Test | Result on Floci 2.1.0 |
|---|---|
| A user with no policy lists buckets | **Denied** (enforcement on) |
| The same user with `AmazonS3ReadOnlyAccess`: list / create a bucket | List **allowed**, create **denied** |
| A user with `AdministratorAccess` and an S3-read-only **permissions boundary**: read S3 / create an IAM user | Read **allowed**, IAM **denied**. The boundary caps the admin policy |
| A forged token claiming `repo:evil-org/evil-repo` against the project's real `yaaf-gha-tofu-apply` role, on your normal Floci | **Accepted.** Floci cannot verify GitHub's signature, so it trusts the claims. This is the gap ADR-0006 recorded |
| A GitHub token with exactly the right claims, with enforcement on | **Rejected** ("issuer is not trusted"): Floci refuses what it cannot verify |
| **IRSA**: a token Floci itself signs for the cluster's OIDC issuer, from `demo/allowed` | **Allowed** |
| The same, from `demo/intruder` | **Denied** by the trust policy's `sub` condition |
| The intruder's token with its subject rewritten to `demo/allowed` | **Rejected**: signature invalid |

The last three rows are the point. IRSA (IAM Roles for Service Accounts) is how a Kubernetes pod gets AWS access, and it
uses the same mechanism as GitHub Actions: a signed token, an OIDC provider registered in IAM, and a trust policy with
`sub` and `aud` conditions. Floci hosts the cluster's issuer, so it enforces all of it. **The trust-policy logic
(`StringEquals` on `sub` and `aud`, signature verification, tamper detection) is therefore proven locally.** What only
real AWS can show is GitHub's *own* issuer: that AWS accepts GitHub's real signing keys and that Actions' real tokens carry
the `sub` this policy expects.

## Why this way

- **Prove locally what can be proven locally.** ADR-0020 first proposed real AWS for the trust test. The drill shows most
  of it does not need real AWS; the remaining question is small and specific.
- **A throwaway Floci for enforcement**, not your environment: turning enforcement on would change what your normal
  tooling can do (below).

## Watch out for

- **The `test` access key always bypasses enforcement**, and so does any key Floci does not know. All the OpenTofu code in
  this repository uses `test`/`test`, so turning enforcement on globally would not restrict it, but it would evaluate the
  `kubectl` user (a real key) and that user has no policy.
- **Conditions are not evaluated for plain `AssumeRole`** on Floci (documented); they are for web-identity tokens from a
  Floci-hosted issuer. Do not read "trust policy passes locally" as "the same condition would pass on AWS".
- **A permissions boundary is a ceiling, not a grant.** A user with only a boundary can do nothing. Both must allow.
- **A wildcard `sub`** (`repo:ya11so22/*`) trusts every repository under that owner, and `StringLike` with a leading
  `*` trusts everything. The plan is to fail such a policy in CI (Phase 2, policy as code).
- **A forged token succeeding is the emulator, not the design.** The design's exact-match `StringEquals` on `sub`
  would refuse it on AWS. That is why this drill exists: to keep the difference visible instead of forgotten.

## Check yourself

<details><summary>What does a permissions boundary stop that an identity policy cannot?</summary>

An identity policy grants; a boundary caps. It stops a principal that is allowed to create roles or attach policies
from granting itself, or a role it creates, more than the boundary allows. That is the standard defence against
privilege escalation inside a delegated-admin setup.

</details>

<details><summary>A CI role trusts `token.actions.githubusercontent.com` with no `sub` condition. What is wrong?</summary>

Any GitHub Actions workflow in any repository can assume the role, because they all carry a valid token from the same
issuer. The `sub` (and `aud`) conditions are what pin it to one repository and branch.

</details>

<details><summary>Why can Floci prove IRSA trust but not GitHub's?</summary>

Floci runs the cluster's OIDC issuer, so it holds the signing key and can verify signatures and claims. GitHub's issuer
is external, so Floci cannot fetch or verify its keys and either trusts blindly (enforcement off) or rejects everything
(enforcement on).

</details>
