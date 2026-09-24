# 2026-09-21: The first end-to-end run: app change to rollout

**Phase:** Phase 1, GitOps delivery
**Related ADRs:** [ADR-0013](../../adr/archive/0013-gitops-with-argo-cd-on-long-lived-aws.md), [ADR-0011](../../adr/archive/0011-cd-image-identity-scope-and-state.md)

## What happened

The bump workflow (PR #12) merged and its first run, on an unchanged tree, minted the App token, checked
out and found the pins current: nothing to do. To exercise the rest, the simulated app team made a real
change (PR #13): a comment-only notice in `emailservice`, which Apache-2.0 asks for on modified files, with
a README line saying app-team changes are marked. The chain then ran on its own:

1. On the PR, `build` built exactly one image (`emailservice`, about a minute), the other 11 were skipped.
2. After the merge, the build on `main` reused that image (its content tag already existed).
3. `bump-images` opened PR #14 as the App bot (`yaaf-project-bot[bot]`): one file, one line, the
   `emailservice` pin `content-244cffe52146` to `content-7e1d31f58204`, auto-merge enabled.
4. Because the PR came from an App token, the required checks ran on it (the reason for using an App), and
   it auto-merged in about a minute.
5. About a minute later Argo CD, tracking `main`, saw the new revision and rolled out `emailservice` only:
   the new pod was Running with 0 restarts, `frontend` untouched, the app still Synced and Healthy, and no
   pod anywhere not Ready. The second `bump-images` run, after the bot PR merged, was a no-op, so there is
   no loop.

## Findings

- **A test that depended on repository state.** `bump-pr.test.sh` failed in CI on the app-change PR: it
  assumed the committed pins were current, but a real app change makes them stale until the bump PR lands,
  which is the case the workflow exists for. It passed locally only because I ran it before committing. The
  test now builds its own current pins in its throwaway clone.
- Argo CD's default poll (about three minutes) sets the delay between the bump merging and the rollout.

## Verification

Observed directly: the bot PR (author, file, diff, auto-merge), the checks on it, the merged commit
`74a630b`, the deployment image, the old pod terminating and the new one Running, Argo `Synced Healthy`.

## Next

The CI check that Argo syncs a PR's commit on a throwaway Floci (replacing `deploy.yml`), then the rollback
drill: revert the bump PR and watch Argo return to the previous image.
