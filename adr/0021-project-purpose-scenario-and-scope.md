# ADR-0021: Project purpose, scenario and scope

**Status:** accepted (consolidates and supersedes ADR-0001, 0010, 0017, 0018 and 0019, now in [`archive/`](archive/))
**Date:** 2026-09-24

## Context

The project's direction was set and reset across five ADRs in five weeks: the target app (0001), the market
positioning and AI phases (0010), the Well-Architected architecture track (0017), the customer scenario (0018)
and the scope cut (0019). Each amended the one before, so the current answer could only be pieced together from a
chain of "amended by" notes. This ADR states the current answer in one place. The history, with the evidence
behind each step, stays in the archive.

The evidence it rests on is the market check of 2026-09-24
([research](../docs/research/2026-09-24-sa-market-and-project-reality-check.md)): at one to two years of
experience the realistic path is a DevOps, platform or cloud engineer role now and a Solutions Architect (SA) role
next; and real postings repeatedly ask for infrastructure as code, CI/CD, written decision records, regulated or
compliance work, migration, Kubernetes, SLOs and monitoring.

## Options considered

1. **Keep the DevOps and platform build-out only** (the 0010 plan). Strong engineering proof, but no design
   artefacts, which is what SA work is.
2. **Turn the project into a design case study.** Good for SA roles, but loses the running system that makes the
   design believable.
3. **One engagement, designed and built** (chosen): a fictional customer's move to AWS, with the design work and
   the running system side by side.
4. **Start again with a new app or stack.** Considered on 2026-09-24 and rejected: the existing repository already
   has the rare parts (decision records, a postmortem, GitOps), and its gaps are fixable in place.

## Decision

1. **Purpose.** A portfolio for DevOps and platform roles now and SA roles next, and a course the owner learns
   from as it is built. Every step is explained in `docs/guides/` as well as recorded.
2. **The engagement.** A **fictional mid-size online retailer that takes card payments** moves its storefront to
   AWS. The storefront runs on-premises today, and one newer feature, the shopping assistant, runs on Google Cloud.
   The project follows one engagement: discovery and requirements, design, a Well-Architected review, build,
   operate, a deliberate failure, and a second review. **PCI DSS** is the control frame, used as a mapping, never
   as a claim of compliance.
3. **The app.** Google's Online Boutique (Apache-2.0) is vendored at upstream commit
   `72ba613a05f7fcee51cf1d0badff401b6ae7074d`, kept to the parts this project uses: `src/`, `protos/`,
   `kustomize/`, the licence and upstream's README. The Google Cloud tooling (Cloud Build, Terraform for GKE,
   Skaffold, Istio, the Helm chart, docs) was removed on 2026-09-24. Services stay upstream's code except the
   shopping assistant, which is replatformed (item 5) with a modification notice.
4. **Two proofs, side by side.** An architecture track in `docs/architecture/` (requirements, views, the
   Well-Architected review with a findings register, reliability and DR, cost, migration, security, AI,
   governance, customer-facing and interview material) and the engineering (the running system, failure
   exercises, postmortems). Each claim carries an evidence label: **designed**, **verified on Floci**, or
   **verified on real AWS**.
5. **The finish line**, in order:
   1. Close Phase 1: threat model, pre-merge deploy check, README demo.
   2. Requirements, views, Well-Architected review v1.
   3. Phase 2, operate it: observability, SLOs and alerts, policy as code, an incident drill.
   4. Phase 3, the replatform: the shopping assistant moves from Gemini, AlloyDB and Google Secret Manager to
      Bedrock (designed), PostgreSQL with pgvector and Secrets Manager (built on Floci), behind a provider
      interface; with a backup-and-restore drill measured against the scenario's RPO.
   5. Cost model and DR design, review v2, the interview kit.
6. **Out of scope:** classic MLOps; a self-hosted LLM as a build (it is weighed on paper in the AI design);
   certifications; a production environment; a multi-account build (designed on paper only). Deferred and
   optional: per-PR environments and DORA metrics.
7. **Team model.** The "app team" is simulated by Claude agents that change `app/src` through pull requests; the
   owner is the platform engineer and code owner of everything else. One GitHub identity does both, so required
   reviews cannot be enforced; `CODEOWNERS` records the intent.

## Rationale

One engagement gives every artefact a single storyline, which is easier to present than a list of tools. The
retailer fits the app as it is, uses the owner's regulated-industry background, and is the kind of work AWS
partners sell. The shopping-assistant replatform turns existing code into a real migration, a RAG design and a
stateful service, which fixes the three gaps the market check found (no state, no migration, no managed AI design).
Pruning the vendored app removes Google Cloud material a reviewer would otherwise have to skip past.

## Consequences / trade-offs accepted

- The customer is fictional; the project shows the method, not client experience, and says so.
- The shopping assistant diverges from upstream; the README's attribution says so.
- Bedrock is designed but not run, because nothing billable is created on real AWS (ADR-0020).
- Pruned upstream files remain in git history; re-vendoring means copying the same paths from the recorded commit.
- Revisit if a later market check shows a different scenario or scope fits the target roles better.
