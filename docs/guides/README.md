# Guides

This project is also a course. The ADRs say **what was decided and why**; the journal says **what happened**; the
guides explain **how the thing works, why it was done this way, and what to watch out for**, so the owner can
learn from each step and explain it later without notes.

## What a guide contains

Every guide uses the same five parts ([template](_template.md)):

1. **The idea**: the concept in plain words, before any tool names.
2. **How it works here**: what this project did, with links to the ADR, the code and the journal entry.
3. **Why this way**: the alternatives and the trade-off, in short; the ADR has the full version.
4. **Watch out for**: the traps, including the ones this project actually fell into.
5. **Check yourself**: a few questions an interviewer could ask, with short answers folded underneath.

## When a guide gets written

- A step introduces a concept that is new to the project (for example OIDC, GitOps, a permissions boundary, RPO).
- A trap was hit that someone else would hit too.
- Not for every change: a small fix goes in the journal, and the relevant guide gets a line under "Watch out for".

## Index

| Guide | Topic | Status |
|---|---|---|
| [Staying at $0 on AWS](aws-cost-safety.md) | Why AWS has no spending cap, what a zero-spend lane is, the account checks | written |
| [The local AWS environment](local-aws-environment.md) | Floci, the three OpenTofu roots, state in S3 with locking, the CloudFront portal, emulator traps | written |
| [Kubernetes probes](kubernetes-probes.md) | Startup, liveness and readiness, through a service that restarted forever | written |
| [Reaching an EC2 instance](reaching-an-ec2-instance.md) | SSH, SSM Run Command and the console terminal; key pairs, user data, security groups, instance profiles | written |
| [IAM policies, boundaries and trust](iam-policies-and-trust.md) | Identity policy vs boundary vs trust policy; what Floci enforces, with a drill | written |
| GitHub OIDC to AWS | Federated identity, trust conditions, why no long-lived keys | to write (backfill, ADR-0006) |
| GitOps with Argo CD | Pull versus push delivery, sync, why rollback means reverting the source | to write (backfill, ADR-0023) |
| Content-hash image tags | Immutable tags, why a tree hash, how bumps work | to write (backfill, ADR-0023) |
| The Well-Architected review | Pillars, lenses, a findings register | to write with review v1 |
| RAG and the assistant replatform | Embeddings, vector search, provider interfaces | to write with Phase 3 |
