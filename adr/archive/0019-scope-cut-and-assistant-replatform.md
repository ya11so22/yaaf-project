# ADR-0019: Cut scope to finish, and replatform the shopping assistant from Google Cloud to AWS

**Status:** superseded by [ADR-0021](../0021-project-purpose-scenario-and-scope.md) (consolidated 2026-09-24; kept as the record of how the decision evolved)
[ADR-0017](0017-well-architected-architecture-track.md) decisions 7 and 8; changes [ADR-0011](0011-cd-image-identity-scope-and-state.md)'s
service scope)
**Date:** 2026-09-24

## Context

The 2026-09-24 reality check ([research](../../docs/research/2026-09-24-sa-market-and-project-reality-check.md))
found three problems. The workload has no real state (only a Redis cart), so recovery point objectives,
point-in-time restore and data migration have nothing to act on. The scope (four phases plus thirteen
architecture milestones) is too wide to finish, and hiring managers name unfinished projects as a red flag. And
the planned AI work (a self-hosted model on CPU, Phase 3; classic MLOps, Phase 4) is less relevant to SA roles
than designing with a managed model service, retrieval and cost trade-offs.

Online Boutique already contains `shoppingassistantservice`, which ADR-0011 left out because it needs Google
Cloud: Gemini for a vision step, text generation and embeddings; AlloyDB (PostgreSQL with vector search) for
retrieval over the catalogue; and Google Secret Manager for the database password.

## Options considered

1. **Replatform `shoppingassistantservice` to AWS services.**
   - Pros: a real cross-cloud migration (the "replatform" R of the 7 Rs) done, not described; a retrieval-augmented
     generation (RAG) design, which SA roles ask for; a stateful service, so backup, restore and RPO can be
     measured.
   - Cons: it changes vendored code, so that one service diverges from upstream; a vision-capable model is heavy
     to run locally.
2. **Add a new service with a database** (for example, an orders service).
   - Pros: full control over the design.
   - Cons: invented code with no migration story; more to build.
3. **Keep the current plan** (self-hosted CPU model, then MLOps).
   - Pros: nothing to re-plan.
   - Cons: keeps the scope and relevance problems above.

## Decision

1. **Replatform the shopping assistant** to its AWS-shaped equivalents, behind the same HTTP interface:
   | Google Cloud (today) | AWS target (designed) | Local (verified on Floci / in-cluster) |
   |---|---|---|
   | Gemini (vision + text) | Amazon Bedrock | A small local model, or a deterministic stub for CI |
   | Gemini embeddings | Bedrock embeddings | A local embeddings model or stub |
   | AlloyDB (pgvector) | RDS or Aurora PostgreSQL with pgvector | PostgreSQL with pgvector |
   | Secret Manager | AWS Secrets Manager | Floci Secrets Manager |
   The model provider sits behind one small interface so switching local ↔ Bedrock is configuration. The exact
   local model and stub design is settled in the implementation ADR.
2. **This becomes Phase 3**, replacing the self-hosted-model plan. Self-hosted serving on EKS stays as the
   alternative weighed in `07-ai-architecture.md`, not as a build.
3. **Phase 4 (classic MLOps) is dropped.**
4. **Deferred, optional:** per-PR environments and DORA metrics (Phase 2 stretch).
5. **Designed only, on paper:** multi-account governance (`08-governance.md`), since one account cannot show it.
6. **The finish line, in order:**
   1. Close Phase 1: threat model, pre-merge deploy check, README demo.
   2. Requirements, views, Well-Architected review v1 with a findings register.
   3. Phase 2 (operate it): observability, SLOs and alerts, policy as code, an incident drill.
   4. Phase 3: the assistant replatform, with a backup-and-restore drill measured against the RPO.
   5. Cost model and DR design, review v2, the interview kit.

## Rationale

One change fixes three gaps at once: it adds state, it is a genuine migration, and it is the AI design SA roles
ask for. It uses code that already exists in the repository, so nothing is invented. Dropping Phase 4 and
deferring the stretch items turns an open-ended plan into one that can be called done, with each step still
useful on its own.

## Consequences / trade-offs accepted

- `app/src/shoppingassistantservice` stops being upstream code. The README's attribution must say it was
  modified (Apache-2.0 allows this with notice), and the work is done as app-team PRs per `CONTRIBUTING.md`.
- The Bedrock path is **designed**, not verified on real AWS, because of the owner's cost limit (ADR-0020). Only
  the local path runs. The docs say which is which.
- The classic MLOps story is gone; recommendation stays a mock service.
- Revisit if the local model cannot run on the owner's hardware; the stub keeps the pipeline and the data layer
  testable either way.
