# 2026-09-20: CD design decisions and milestone bookkeeping

**Phase:** Phase 1, continuous delivery (design only)
**Related ADRs:** [ADR-0011](../../adr/0011-cd-image-identity-scope-and-state.md)

## What happened

PRs #4 (cleanup delete-count fix) and #5 (ADR-0010 repositioning) were merged after green checks.
The three blocking CD questions were answered and recorded as ADR-0011. `docs/milestones.md` had
still listed them as open, so it was corrected, and two items were added: a spike to prove a
throwaway Floci with EKS works on a GitHub-hosted runner, and the `build.yml` change for
content-hash tags. I had also said the work was ready to move to the CD build; it is not, because
of that spike and the AWS account prerequisite.

## Why

See ADR-0011.

## Verification

Documentation only; `scripts/check` and the CI gates run on the PR.

## Next

Spike Floci-on-a-runner, then content-hash tags in `build.yml`, then the `deploy/` overlays.
