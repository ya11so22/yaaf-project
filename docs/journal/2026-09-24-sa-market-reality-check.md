# 2026-09-24: SA market research and a reality check of the project

**Phase:** cross-cutting (architecture track, ADR-0017)
**Related ADRs:** [ADR-0012](../../adr/archive/0012-local-first-real-aws-deferred.md), [ADR-0017](../../adr/archive/0017-well-architected-architecture-track.md)

## What happened

The owner asked for a re-think of the whole project against the real Solutions Architect and DevOps job market,
open to scrapping it. Web research plus eight real postings pulled from Indeed are written up in
[`docs/research/2026-09-24-sa-market-and-project-reality-check.md`](../research/2026-09-24-sa-market-and-project-reality-check.md).
The verdict there: keep the repo, reframe it as one customer engagement, give the workload real state by
replatforming `shoppingassistantservice` from GCP to AWS (Bedrock plus Postgres/pgvector), use real AWS for
short, capped proof runs, and cut scope so it can finish.

During the session the owner pointed out that their AWS account is over a year old. That was checked: the new
$100–200 Free Tier credits are for new accounts only, one per person, and making a second account to get them
breaks AWS's terms. The real-AWS proposal was changed to a small capped budget (about $25) on the existing
account, with automated teardown as the actual protection.

## Why

ADR-0017 committed to SA-facing work on thin evidence (no real postings). This fills part of that gap and tests
ADR-0012's premise that real AWS is unaffordable: short proof runs are affordable, but not free for this owner.

## Verification

Research only; nothing built. The sources and the confidence of each claim are in the research file. The
postings sample is 8 hand-picked postings, so the SA postings tally milestone stays open.

### Second part: the owner's answers

The owner answered: no AWS spend and no risk of accidental spend at all; the payments retailer; the scope cut;
the certification later and out of scope; and the project should teach them as it goes. Recorded as:

- [ADR-0018](../../adr/archive/0018-scenario-card-payments-retailer.md) (accepted): one engagement with a card-payments
  retailer, PCI DSS as a mapping.
- [ADR-0019](../../adr/archive/0019-scope-cut-and-assistant-replatform.md) (accepted): Phase 3 becomes the shopping
  assistant replatform, Phase 4 dropped, DORA and per-PR environments deferred.
- [ADR-0020](../../adr/0020-zero-spend-real-aws-lane.md) (proposed): real AWS only for IAM and STS, which AWS
  documents as no-charge, through an identity with a permissions boundary. The capped budget was withdrawn,
  because AWS has no hard cap and the risk is an accident, not the planned spend. A free AWS Builder Center
  sandbox (July 2026, workshop-only) was found and noted for learning.
- A learning layer: `docs/guides/` with a template and index, the first guide
  ([staying at $0 on AWS](../guides/aws-cost-safety.md)), a "Learn" section in the journal template, and a standing
  rule in `CLAUDE.md` and `CONTRIBUTING.md`. `CONTRIBUTING.md`'s cost guardrail was rewritten to match.
- Milestones, the architecture README, `CONTEXT.md` and the status lines of ADR-0010, 0011, 0012 and 0017 updated.

## Learn

- AWS has no hard spending cap on a paid account: alerts are late and budget actions do not delete resources, so
  the only reliable cost control is making billable resources impossible to create
  ([guide](../guides/aws-cost-safety.md)).
- Free Tier credits are one per person and new accounts only; a second account to get them breaks the terms.

## Next

1. The owner accepts or changes ADR-0020, then does the account checks in the cost guide (console only).
2. Close Phase 1: threat model, pre-merge deploy check, README demo.
3. Write `docs/architecture/00-requirements.md` for the retailer (targets and the customer's fictional budget).
4. Backfill guides for Phase 1 concepts.
