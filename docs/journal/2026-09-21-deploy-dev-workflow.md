# 2026-09-21: deploy.yml: CD to dev

**Phase:** Phase 1, continuous delivery
**Related ADRs:** [ADR-0008](../../adr/0008-phase-reslice-cd-and-team-model.md), [ADR-0011](../../adr/0011-cd-image-identity-scope-and-state.md), [ADR-0012](../../adr/0012-local-first-real-aws-deferred.md)

## What happened

`deploy.yml` folds the runner spike into a real workflow: start Floci from the shared compose file,
apply the environment, mint an IAM key and build a kubeconfig, render `deploy/dev` at a revision,
apply it, wait for every rollout, then port-forward the frontend and require `/_healthz` and the
shop title, and finally destroy and stop Floci. The rendered manifests are uploaded as an artifact
and the pinned image list goes in the job summary. It runs on merge to `main`, on PRs that touch the
deploy inputs, and by hand: `workflow_dispatch` with a `rev` renders and deploys an earlier revision,
which is the rollback path. The spike workflow was deleted.

## Findings

- First run failed at "Point kubectl at the cluster": I had put `kubectl wait` in the same step that
  exports the new key through `GITHUB_ENV`, so it still ran with `test/test`, which Floci's EKS auth
  rejects. The spike had it in a separate step, which is why it worked there. Fixed by splitting it.
- With the fix, the job took about 2m43s: all 11 rollouts completed (10 services and `redis-cart`)
  and the frontend answered, so service-to-service calls work, not just pod startup.

## Verification

The PR run on the fixed commit passed every step. `workflow_dispatch` cannot be exercised until the
workflow is on `main`, so the rollback path is untested.

## Next

Once merged: run a rollback drill (dispatch with an earlier `rev`), then the Phase 1 failure exercise
(a bad image, recovered by rollback) with a postmortem, the threat model, and the demo.
