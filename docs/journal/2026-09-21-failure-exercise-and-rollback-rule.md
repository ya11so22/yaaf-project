# 2026-09-21: The Phase 1 failure exercise, and the rollback rule it changed

**Phase:** Phase 1, close-out
**Related ADRs:** [ADR-0013](../../adr/archive/0013-gitops-with-argo-cd-on-long-lived-aws.md)
**Postmortem:** [2026-09-21-phase1-bad-emailservice](../postmortems/2026-09-21-phase1-bad-emailservice.md)

## What happened

After the ingress, Headlamp and webhook work were merged and confirmed, the rollback drill became the Phase 1
failure exercise. A comment-only "notice" change had already passed through the pipeline once. This time the
app team merged a change that makes `emailservice` raise at start-up (image builds, CI passes), and the
pipeline delivered it: bump PR, auto-merge, Argo CD rollout. State was recorded every 10 seconds. Two
recoveries were tried: a pin-only revert, then a source revert. Full timeline, blast radius and follow-ups are
in the postmortem.

## What it changed

The drill contradicted a claim in three places (ADR-0013, the glossary, the bump PR body) that reverting the
bump PR rolls back. It does, for about a minute: the bump workflow recomputes the pins from the source on every
build of `main`, so it re-pinned the broken image 21 seconds after the cluster healed. The rule is now
"revert the source change"; the docs and the PR text the bot writes are corrected.

## Verification

Observed directly, with the cluster and GitHub timestamps in the postmortem. No user impact was observed: the
old pod kept serving (the shop returned HTTP 200 when sampled once) because the rollout starts the new pod
before removing the old one and the new one never became Ready.

## Next

Follow-ups in the postmortem, none built: a pre-merge check that starts changed services on a throwaway cluster
(it would have blocked the change), an alert on a stuck rollout, and, only if a pin-only rollback is ever needed,
a way to hold the bump workflow. Then the threat model and the Phase 1 demo.
