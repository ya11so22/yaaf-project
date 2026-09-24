# ADR-0020: Real AWS only where it cannot cost money: a zero-spend lane

**Status:** proposed (waits for the owner's approval; replaces the real-AWS milestone of the archived [ADR-0012](archive/0012-local-first-real-aws-deferred.md))
**Date:** 2026-09-24

## Context

The owner cannot risk any AWS charge, including by accident. Their AWS account is over a year old, so it is on the
legacy Free Tier, whose 12 months have ended, and it bills normally. The new $100–200 credits are for new accounts
only, and AWS's terms bar opening another account to get them. A paid AWS account has **no hard spending cap**:
budget alerts arrive hours after the spend, and budget actions can only attach deny policies or stop EC2 and RDS
instances, not delete an EKS cluster or a NAT gateway.

At the same time, some claims in this project can only be settled on real AWS. The most important is ADR-0006's
GitHub OIDC trust design (Floci does not enforce trust conditions, so the negative test that a foreign repository
cannot assume the role has never run). AWS states that IAM, IAM Identity Center and STS "are features of your AWS
account offered at no additional charge" ([IAM docs](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html)).

## Options considered

1. **Stay fully local.**
   - Pros: zero risk.
   - Cons: the OIDC design stays unproven forever.
2. **A capped budget on the existing account** (the earlier proposal: about $25, with automated teardown).
   - Pros: proves EKS, load balancers, TLS and restores for real.
   - Cons: the risk is not the planned cost but a mistake, and there is no hard cap. Ruled out by the owner.
3. **A zero-spend lane:** real AWS only for services that are free by construction, reached only through a role
   that cannot create anything billable.
   - Pros: the OIDC trust design is proven on real AWS at $0; the guardrails themselves are good IAM practice to
     show.
   - Cons: covers identity only; everything else stays on Floci or designed.
4. **AWS's free sandboxes** (AWS Builder Center sandbox, launched July 2026: no account or card, 8 hours a week,
   tied to specific workshops).
   - Pros: real AWS with no risk.
   - Cons: workshop content only; cannot run this repository's code. Useful for learning, not for evidence.

## Decision

Option 3, with option 4 used for learning on the side. Concretely:

1. **Nothing billable is ever created on the owner's account.** Billable work (EKS, load balancers, NAT, RDS,
   Bedrock) stays on Floci or is **designed** with a cost estimate from the AWS Pricing Calculator (free, no
   account needed).
2. **The lane allows IAM and STS only.** The identity OpenTofu uses on real AWS can manage IAM on project-named
   resources and nothing else. Every role it creates must carry a **permissions boundary** that also allows
   nothing billable, and it cannot remove that boundary, so a bug or a stolen token cannot escalate into a role
   that launches resources. The GitHub OIDC role itself needs no permissions at all: the proof is that it can be
   assumed (`sts:GetCallerIdentity` needs no permission).
3. **Account hygiene first, done by the owner:** MFA on the root user, no root access keys, a check that nothing
   is already running or billing in the account, and a **zero-spend budget** (alerts at $0.01) as a tripwire,
   not a brake.
4. **The first run** proves ADR-0006: GitHub Actions assumes the role through OIDC from this repository, and the
   negative test from another repository (and another branch) is refused. Evidence: logs and CloudTrail event
   history (free, 90 days, no trail needed).
5. **Not used:** CloudTrail trails to S3, IAM Access Analyzer unused-access analysis, and anything else that bills,
   even at cents.

## Rationale

The owner's constraint is about accidents, not about planned spend, so the only safe design is one where an
accident cannot create cost. Restricting the credentials, not relying on alerts, gives that. It also proves the
one claim that most needs real AWS, and least privilege with permissions boundaries is itself an interview topic
(it prevents a known IAM privilege-escalation path).

## Consequences / trade-offs accepted

- Evidence label "verified on real AWS" applies only to identity. EKS, TLS, load balancer health, multi-AZ and
  restores stay "verified on Floci" or "designed", and the review says so.
- Revisit if credits arrive without a new account (AWS Community Builders, next intake about January 2027):
  credits still do not cap spend, so a revisit needs its own guardrail design.
- `CONTRIBUTING.md`'s cost guardrail already follows this lane; ADR-0022 assumes it for the local environment.
