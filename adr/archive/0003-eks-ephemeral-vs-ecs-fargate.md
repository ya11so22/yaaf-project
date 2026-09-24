# ADR-0003: Ephemeral EKS over ECS Fargate as the compute target

**Status:** superseded by [ADR-0022](../0022-the-local-aws-environment.md) (consolidated 2026-09-24; kept as the record of how the decision evolved)
**Date:** 2026-08-22

## Context
Need a container orchestration target for the 11 Online Boutique services. Real EKS has a
~$0.10/hr control plane fee (~$73/mo if left running continuously); ECS Fargate has no such
fixed cost. Project goals explicitly include platform engineering, which is more
Kubernetes-native than ECS-native in how the industry currently talks about it.

## Options considered
1. **ECS Fargate.**
   - Pros: no control-plane fee, zero idle cost, simpler operational model.
   - Cons: shallower story for platform/Kubernetes-flavored roles specifically — less to say
     in an interview that's probing K8s depth.
2. **Real EKS, left running.**
   - Pros: deepest, most direct K8s story.
   - Cons: ~$73/mo if not actively managed — conflicts with the free/cheap goal.
3. **EKS, made ephemeral (spin up for work sessions/demos, destroy after).**
   - Pros: real EKS-flavored depth (via Floci locally, real EKS for milestone validation per
     ADR-0002) without the always-on cost; the ephemeral-environment pattern itself is a
     legitimate platform-engineering artifact worth describing.
   - Cons: requires actual discipline to destroy after each session — a forgotten cluster
     could rack up real cost; needs the AWS Budgets/billing-alarm guardrail from ADR-0002 as a
     backstop.

## Decision
Ephemeral EKS (Option 3): real EKS used only for periodic milestone validation runs (per
ADR-0002), Floci's EKS emulation used for the day-to-day loop, nothing left running
persistently.

## Rationale
Given the explicit goal of leaning into platform engineering, "I ran real EKS" carries more
weight than "I ran Fargate" when the conversation turns to Kubernetes specifics — but leaving
a real cluster running conflicts directly with the free/cheap constraint. Making it ephemeral
gets both: genuine EKS exposure at milestone points, near-zero steady-state cost otherwise.

## Consequences / trade-offs accepted
- Billing alarm (from ADR-0002) is the safety net if a teardown is forgotten — treat it as
  mandatory, not optional, given this ADR depends on discipline to hold.
- If ephemeral EKS proves too fiddly in practice (teardown failures, drift), fall back to
  Fargate for the real-AWS milestones and note that as a superseding decision rather than
  silently drifting away from this ADR.
