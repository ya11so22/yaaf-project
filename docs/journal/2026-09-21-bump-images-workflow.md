# 2026-09-21: The image-bump workflow

**Phase:** Phase 1, GitOps delivery
**Related ADRs:** [ADR-0013](../../adr/0013-gitops-with-argo-cd-on-long-lived-aws.md), [ADR-0011](../../adr/0011-cd-image-identity-scope-and-state.md)

## What happened

PR #11 was merged (ADR-0013 and ADR-0014, `dev-up`, the Argo CD module, the committed pins, Headlamp,
the Traefik plan). The next piece of ADR-0013 is the workflow that keeps the pins current.

`bump-images.yml` runs after a successful `build` of a push to `main` (a `workflow_run` trigger, and only
for `push` events, so it never runs against pull-request code). It mints a short-lived token for the
GitHub App, checks out the built commit, and runs `bump-pr.sh`, which:

- runs `bump-images.sh --verify`, so a pin can never point at an image that was not built;
- does nothing if the pins are already current;
- otherwise commits the change on one fixed branch, `bot/bump-images`, as the bot, force-pushes it, opens
  a PR if none is open (or updates the open one), and enables auto-merge.

Reverting the merged PR rolls the pins back, and Argo CD converges. (Corrected the same day: this holds only until
the next build on `main`, which recomputes the pins from the source; see the failure-exercise postmortem.)

## Why

- **A GitHub App token, not `GITHUB_TOKEN`:** pull requests created with the default token do not trigger
  workflows, so the required checks would never report and the PR could never merge (ADR-0013 decision 4).
- **`client-id`, not `app-id`:** the token action deprecates `app-id` in v3.2.0, so the workflow uses the
  Client ID, stored as a `BOT_CLIENT_ID` secret beside the private key.
- **Logic in a script, workflow kept thin:** the earlier deploy workflow failed twice on shell embedded in
  YAML. `bump-pr.sh` runs in a throwaway clone in dry-run mode, in `scripts/check`, so it is tested before
  it ever runs on GitHub.

## Verification

`bump-pr.test.sh` (7 checks) covers: nothing happens when pins are current, no branch is created then; a
stale pin produces a bump commit on `bot/bump-images` authored by the bot, whose message lists the old pin,
touching only the kustomization, with nothing pushed in dry run. Two test problems were fixed on the way: a
Windows working tree has CRLF line endings where the script writes LF, and a `` in a patch was turned into
a real carriage return. `actionlint` passes on the workflow. The GitHub side (token, PR, auto-merge) cannot
be tried locally and is to be confirmed on the first real run.

## Next

Before the first run: add the `BOT_CLIENT_ID` secret and turn on "Allow auto-merge". Then the CI check that
Argo syncs a PR's commit on a throwaway Floci (replacing `deploy.yml`), and the rollback drill.
