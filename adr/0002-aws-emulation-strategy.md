# ADR-0002: Floci-first local AWS emulation, with periodic real-AWS validation milestones

**Status:** accepted
**Date:** 2026-08-22

## Context
Goal is to build real AWS IaC/architecture skill at free/cheap cost, with fast daily iteration
in GitHub Actions CI. Running everything against real AWS continuously is neither free nor
fast to iterate against; running everything against an emulator forever risks masking real
AWS behavior gaps.

## Options considered
1. **Real AWS only, kept small/free-tier.**
   - Pros: no fidelity gap, ever.
   - Cons: slower iteration loop, real risk of unexpected cost, CI runs cost real money/time
     against a live account.
2. **Local emulation only (Floci), never touching real AWS.**
   - Pros: zero cost, fast (Floci starts in ~24ms, ~13 MiB idle memory), CI-friendly as a
     GitHub Actions service container, MIT-licensed, drop-in AWS SDK/CLI/Terraform
     compatibility on port 4566.
   - Cons: Floci's EKS support specifically is "mock + k3s" under an EKS-shaped API — good for
     proving the platform workflow (Terraform applying, Actions orchestrating, IAM/networking
     concepts) but not a substitute for real EKS-specific nuance (IRSA behavior, real
     networking edge cases). Compatibility is validated against tested SDK calls, not full
     behavioral parity with AWS.
3. **Hybrid: Floci for daily dev loop + all CI, real AWS for periodic milestone validation.**
   - Pros: gets the speed/cost benefits of #2 for 95% of the work, while still proving the same
     Terraform + Actions pipeline against genuine AWS before calling a phase "done." Real-AWS
     spend is minimal since it's only spun up briefly per milestone and torn down immediately.
   - Cons: slightly more process (need a distinct "validate against real AWS" step per phase),
     requires care that the two environments don't silently drift apart.

## Decision
Hybrid approach (Option 3): Floci as the default for local development and all GitHub Actions
CI runs; one real (temporary, torn-down) AWS deployment per phase as a milestone validation.

## Rationale
This gets genuinely free, fast iteration for the vast majority of the work, while still
producing an honest claim: "built emulator-first for cost and speed, validated against real
AWS before considering it done." That's a legitimate, describable platform-engineering
practice in its own right (fast inner loop + real validation gate), not just a workaround for
being on a budget — and it directly manages the known EKS-fidelity gap by not depending on the
emulator for the parts of the story that need to be genuinely real.

## Consequences / trade-offs accepted
- AWS Budgets + a billing alarm set up before any real-AWS milestone run, as a hard guardrail.
- Real-AWS milestones need to be actually run, not skipped as "probably fine" — that's where
  the honesty of the claim comes from.
- If Floci's EKS emulation improves significantly, this ADR should be revisited — the fidelity
  gap that justifies the milestone-validation step may narrow over time.
