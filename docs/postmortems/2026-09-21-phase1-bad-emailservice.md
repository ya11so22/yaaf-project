# 2026-09-21: A broken emailservice through the delivery pipeline (Phase 1 failure exercise)

**Type:** deliberate failure exercise. **Environment:** `dev` (Argo CD on the long-lived local AWS).
**Related:** [ADR-0013](../../adr/archive/0013-gitops-with-argo-cd-on-long-lived-aws.md), [ADR-0011](../../adr/archive/0011-cd-image-identity-scope-and-state.md), PRs #17 to #22.

## What broke, and how it was broken on purpose

The simulated app team merged a change (#17) that makes `emailservice` raise at import time. The
Dockerfile builds fine, so every CI check passed and the image was published. The pipeline then did what it
is built to do: the bump workflow opened and auto-merged a PR pinning the new image (#18), and Argo CD
rolled it out.

## Timeline (UTC, from GitHub and the cluster; state sampled every 10 seconds)

| Time | Event |
|---|---|
| 13:29:20 | #17, the broken change, merges (checks passed) |
| 13:29:37 | Argo CD syncs the new `main` (17 s after the merge, by webhook); no image change yet |
| 13:31:09 | Bot PR #18 (pins the broken image) auto-merges |
| 13:31:21 | Argo CD syncs it (12 s later). New pod `CrashLoopBackOff`, `RuntimeError: failure drill...`. Old pod stays Ready. App: `Progressing` |
| 13:31:37 | Detected by hand. Shop returns HTTP 200 through the ALB; `rollout status` times out |
| 13:32:04 | Recovery attempt 1: PR #19 reverts only the pin |
| 13:32:39 | #19 merges. 13:32:52: Argo `Healthy`, image back to the good tag, bad pod gone |
| 13:33:13 | **The bump workflow opens #20, re-pinning the broken image** (the source is still broken) |
| 13:33:54 | #20 auto-merges. 13:34:10: broken image rolled out again |
| 13:34:25 | Recovery attempt 2: PR #21 reverts the source change |
| 13:35:07 | #21 merges. Its content tag returns to the good image, which is already on GHCR, so nothing is rebuilt |
| 13:35:51 | Bot PR #22 pins the good image; merges 13:36:21 |
| 13:36:32 | Argo `Synced Healthy`, good image, one Ready pod. **Recovered and stable** |

Broken image in the cluster: 13:31:21 to 13:32:52 (1 min 31 s) and 13:34:10 to 13:36:32 (2 min 22 s).
First bad rollout to durable recovery: 5 min 11 s. From opening the source revert to healthy: 2 min 7 s.

## Blast radius

None observed by users. The `emailservice` Deployment rolls out with `maxSurge=25%` and, with one replica,
`maxUnavailable` rounds down to 0, so the old pod kept serving while the new one never passed its readiness
probe. The shop answered HTTP 200 at the one point I sampled (13:31:37), not continuously. `emailservice` is
only called for order confirmations, so a real outage would have shown up there. Nothing else failed; no other
pod was ever not Ready.

## How it was caught (or was not)

- **Not by CI.** The change is valid Python and the image builds; it fails only when the process starts. No
  check starts the service before merge.
- **Not by an alert.** No alert exists yet (Phase 2). Argo CD showed the app `Progressing`, not `Degraded`,
  because the Deployment only reports failure after its progress deadline (600 s). It was noticed because I was
  watching.
- **Not by the older post-merge deploy check.** That workflow (a throwaway Floci deploy on every push to `main`)
  was cancelled by the next push on each of the three commits that pinned the broken image (`8f4baae`,
  `69fcc0d`, `86e05ec`), so it never reported. It also runs only after merge.

## What we learned

1. **A pin-only revert does not stick.** Pins are derived from the source: the bump workflow recomputes them
   from the source tree after every `main` build. Reverting only the pin healed the cluster 48 seconds after the PR was opened
   and the broken image was back 78 seconds after that. The correct rollback is to revert the change that caused the problem. That
   returns the content tag to the earlier value, so nothing needs rebuilding.
2. **The webhook works under real conditions.** Argo CD synced 11 to 17 seconds after each merge (GitHub's
   merge time to the cluster state, sampled every 10 seconds), against up to three minutes with polling.
3. **The rollout strategy and readiness probe are what contained it,** not the pipeline. The pipeline delivered
   the fault efficiently and automatically.

## What changed as a result

- The rollback rule is now written down where the old text was wrong: ADR-0013 (rollback is reverting the
  source; a pin revert alone is undone by the next bump), the glossary, README, and the PR body the bump
  workflow writes.
- Follow-ups, none built yet:
  - **Catch it before merge:** a check on app pull requests that deploys the changed services to a throwaway
    cluster and waits for the rollout. This is the planned "CI verifies CD on a throwaway Floci" item, and it
    would have blocked #17.
  - **Alert on a stuck rollout** (Phase 2, alongside the SLOs), without waiting for the progress deadline.
  - **An emergency brake:** if a pin-only rollback is ever needed quickly (for example while the fix is being
    written), the bump workflow needs a way to be held, such as a marker file it checks. Not needed while
    rollback means reverting the source.
  - **Make the older post-merge deploy check less fragile** under rapid merges, or retire it once the
    pre-merge check exists.
