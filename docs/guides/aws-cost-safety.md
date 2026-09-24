# Guide: Staying at $0 on AWS

**Related:** [ADR-0020](../../adr/0020-zero-spend-real-aws-lane.md) (proposed), [ADR-0012](../../adr/archive/0012-local-first-real-aws-deferred.md),
[research](../research/2026-09-24-sa-market-and-project-reality-check.md)
**Evidence:** designed (the lane is not built yet)

## The idea

AWS charges for what runs, by the hour or by the request, and bills at the end of the month. On a normal (paid)
account **there is no switch that stops spending at a limit**. Everything AWS offers for cost control either
*tells* you (alerts) or *restricts future actions* (deny policies). None of it deletes what is already running.
So the only way to be sure an accident costs nothing is to make sure an accident **cannot create** anything that
bills.

## How it works here

Three places to run things, each with a job:

| Where | Cost | Used for |
|---|---|---|
| Floci on your machine | $0 | Everything that would bill on AWS: EKS, load balancers, databases, the pipeline |
| Your AWS account, IAM and STS only | $0 (AWS: IAM, Identity Center and STS are "offered at no additional charge") | Proving the GitHub OIDC trust design, which Floci cannot enforce |
| AWS Builder Center sandbox | $0, no card | Learning real services in AWS's own workshops, 8 hours a week |

Billable services are still **designed** properly: a diagram, a cost estimate from the
[AWS Pricing Calculator](https://calculator.aws/) (free, no account needed) and the reasoning. Estimating cost
without spending it is itself architect work.

### Before anything touches your account (you do these, in the console)

1. **Check nothing is running now.** Billing → Bills: the current month should show $0.00. Then check each Region
   you have used (EC2, RDS, EKS, NAT gateways, Elastic IPs, load balancers, EBS volumes and snapshots, S3). Old
   accounts often have a leftover volume or IP address.
2. **Root user:** turn on MFA; delete any root access keys; do not use root for daily work.
3. **Create a zero-spend budget.** Billing → Budgets → Create → "Use a template" → "Zero spend budget". It emails
   you when spend passes $0.01. Treat it as a smoke alarm, not a fire door.
4. **Create a limited identity for the project**, allowed IAM and STS only, with a permissions boundary (the lane
   in ADR-0020). Never give the project an administrator identity.

## Why this way

- **A capped budget with automated teardown** was the first proposal (about $25). It was dropped because the risk
  is not the planned spend; it is a mistake that leaves something running, and nothing stops that in time.
- **A new account for the $200 credits** is not allowed: credits are for new customers, one per person, and AWS's
  terms say making more accounts to get offers removes eligibility.
- **Staying fully local** would leave the OIDC design unproven. IAM is free, so it does not need to be.

## Watch out for

- **Alerts are late.** Billing data updates a few times a day. A NAT gateway can run for hours before an email arrives.
- **Budget actions do not delete.** They can attach a deny policy or stop EC2 and RDS instances. An EKS cluster,
  NAT gateway or load balancer keeps billing.
- **"Free Tier" is not a shield.** Some things always bill: NAT gateways (about $0.045 an hour), public IPv4
  addresses ($0.005 an hour each), CloudWatch Logs without a retention setting, data transfer between zones.
- **Things that bill without looking like servers:** EBS snapshots, stopped instances' volumes, unattached
  Elastic IPs, KMS customer keys (about $1 a month each), Secrets Manager secrets (per secret per month).
- **An IAM-only role can still escalate** if it can create a new role without a boundary and then use it. That is
  why every role the project creates must carry the boundary, and the project identity cannot remove it.
- **Credits do not cap spend either.** When credits run out on a paid account, billing just continues.
- **Leaked keys are the worst case.** Keys pushed to a public repo get used by attackers within minutes to launch
  instances. This is why the project uses OIDC (no stored keys) and gitleaks in the pre-gate.

## Check yourself

<details><summary>A customer asks you to "put a hard limit on our AWS spend". What do you tell them?</summary>

AWS has no hard cap on a paid account. You combine layers: prevention (least-privilege roles, service control
policies that block expensive services, permissions boundaries), detection (budgets and anomaly detection, which
are late by hours), and response (budget actions or automation that stop or delete resources). The strongest
control is prevention, because the others act after the spend has started.

</details>

<details><summary>What is a permissions boundary, and what does it stop?</summary>

A managed policy attached to a role or user that sets the maximum permissions it can ever have, whatever its own
policies say. The effective permission is the overlap of the two. It stops an identity that is allowed to create
roles from creating one more powerful than itself.

</details>

<details><summary>Why can you prove the OIDC design for $0 but not the EKS cluster?</summary>

IAM and STS are free, and assuming a role creates nothing billable. EKS charges per cluster-hour for the control
plane, plus nodes, NAT and load balancers.

</details>
