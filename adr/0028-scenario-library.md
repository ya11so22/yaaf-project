# ADR-0028: Failure exercises become a library of scenarios

**Status:** accepted (refines the "failure exercise per phase" practice in `CLAUDE.md` and [ADR-0021](0021-project-purpose-scenario-and-scope.md))
**Date:** 2026-10-03
**Evidence:** designed.

## Context

The project promises one deliberate failure per phase. So far there is one good example, the bad emailservice run
(`docs/postmortems/2026-09-21-phase1-bad-emailservice.md`: a timeline from real events, blast radius, how it was
caught, and a lesson that changed an ADR), and one script, `scripts/drills/iam-trust.sh`, which prints allow and deny
results. That script shows a mechanism; it is not an incident. The owner wants exercises that reflect real-world
failures, are presentable, and can be expanded over time. The project is run by one person, so the written record is
the product and the running exercise is how its evidence is produced honestly.

## Options considered

1. **One exercise per phase, as now.** Few, unrelated to each other, and easy to skip.
2. **Scripted demos that print results.** Easy to build, and they teach a mechanism rather than an incident.
3. **A library of scenarios, each written before it is run** (chosen).

## Decision

1. **A scenario is a folder, `docs/scenarios/<name>/`**, holding `spec.md` and `inject.sh`.
   - `spec.md` is written first and labelled *designed*: the business story in the retailer's terms, the real-world
     failure family it stands for, the fault, what should detect it, what is expected to happen, and how to recover.
   - `inject.sh` causes the fault and only that; it leaves a clear way to undo it.
2. **Every run produces a dated report in `docs/postmortems/`** in the existing format (what broke, blast radius, how it
   was caught, what changed), and the spec links to its runs. The label becomes *verified on Floci*. A hypothesis in
   the spec that turned out wrong is retracted in the report, not quietly edited (the honesty rule).
3. **The first set**, chosen from real incident families:
   - Scenario 0, already run: the bad emailservice through the pipeline.
   - Configuration drift: a live Deployment edited by hand and reverted by Argo CD's self-heal.
   - Losing the platform: the cluster wiped and rebuilt from git, with the recovery time measured (a disaster-recovery
     test of the platform).
   - Stuck or lost state: an OpenTofu lock stuck or the state bucket damaged, recovered from the versioned bucket.
   - A leaked credential: a key committed, caught by gitleaks, rotated.
   - A tag rewrite in the supply chain: an action's tag moved to malicious code (the March 2026 Trivy attack), stopped
     by SHA pins and zizmor.
   - Overbroad trust: the OIDC role given a wildcard `sub`, so any repository could assume it. This is
     `iam-trust.sh` rewritten as an incident; policy as code on the plan (Phase 2) is the fix.
   - A mislabelled image (ADR-0027): an amd64 image shipped as arm64, caught by the architecture check.
4. **After monitoring exists (Phase 2)**: a failing downstream dependency (redis-cart down) seen as an SLO burn, and
   capacity exhaustion (a memory limit set too low).
5. `scripts/drills/iam-trust.sh` moves into its scenario folder. New scenarios are new folders; nothing else changes.

## Rationale

Real postings ask for incident handling, postmortems and SLOs. A scenario written before it is run records what was
*expected*, which makes the report an honest comparison and not a story told afterwards. One folder per scenario keeps
the library easy to extend and each one self-contained.

## Consequences / trade-offs accepted

- Some scenarios (the monitoring-dependent ones) cannot be run until Phase 2; their specs can be written earlier.
- Scenarios that attack the supply chain are simulated against a repository-local action or a throwaway repository,
  never against a real third-party project.
- A scenario that damages state or the cluster must be safe to run on the owner's long-lived environment, which is why
  `reset` and the opt-in recovery steps are tasks, not manual steps.
- Acceptance for the library: the first non-monitoring scenario is specified, run and reported end to end, and the
  report changes something (an ADR, a check, a guide).
