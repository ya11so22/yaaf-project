# 2026-09-20: Market research and repositioning for US roles

**Phase:** Phase 1 to 4 roadmap (planning, no infrastructure changed)
**Related ADRs:** [ADR-0010](../../adr/0010-us-market-positioning-and-ai-phases.md), amends [ADR-0008](../../adr/0008-phase-reslice-cd-and-team-model.md)

## What happened

The owner asked whether this project is actually worth presenting for a DevOps engineer with 2-3
years of experience, and said it could be redefined. I ran a multi-agent deep-research pass (99
agents, 17 sources, 67 claims, top 25 each verified by three votes). 14 claims were confirmed and
11 refuted. The sources were almost all recruiter and career blogs, so the evidence is thin and
the ADR says so.

The owner then asked why MLOps had been dropped from my first summary and whether AI work is not
the current big thing, with the US market as the focus. I had dropped it without evidence and
retracted that. A lighter search pass (unverified) pointed to strong US demand for AI infrastructure,
described as platform and SRE work for ML systems.

Decisions, from the owner: keep AI in scope, LLM serving first and classic MLOps after ("a then b"),
and relocation to the US is the goal (treated as a career plan outside the repo).

Documents updated: ADR-0010 (new), ADR-0008 status line, README (pitch, phases table, ADR list),
`docs/milestones.md` (Phases 2 to 4 rewritten, Phase 1 gains rollback, real-AWS evidence and a
negative trust test), `docs/live-infra-gap-analysis.md` (observability row), `CONTEXT.md`.

## Why

See ADR-0010. In short: the project shows how things are built better than how they are run, so
the operate-it work (CD with rollback, SLOs, an incident drill) goes ahead of the AI phases, which
then build on it.

## Verification

Documentation only. Relative links and `scripts/check` were run before committing; CI runs the
same check on the PR.

## Next

The CD design is blocked on three open questions: how a deploy identifies the current image per
service under path-filtered builds (content-hash tags recommended), what gets deployed (11 base
services without the load generator), and how the milestone holds state. PR #4 (cleanup
delete-count fix) is also awaiting a merge decision.
