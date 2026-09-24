# 2026-09-20: Spike: Floci with EKS and a GHCR rollout on a GitHub runner

**Phase:** Phase 1, continuous delivery (de-risking the dev deploy)
**Related ADRs:** [ADR-0008](../../adr/archive/0008-phase-reslice-cd-and-team-model.md), [ADR-0012](../../adr/archive/0012-local-first-real-aws-deferred.md)

## What happened

ADR-0008 assumed a throwaway Floci with EKS could run on a GitHub-hosted runner and take a deploy.
The infra smoke test already applied the environment there, but nothing had reached the cluster.
`spike-floci-deploy.yml` starts Floci with the same compose file used locally, applies the
environment (53 resources), mints an IAM key in Floci, builds a kubeconfig with
`aws eks update-kubeconfig`, waits for the node, then creates a deployment from a real GHCR image
(`currencyservice`) and waits for the rollout.

Result: it works. Apply took 29s, the k3s node (v1.36.4) was Ready about 10s after apply, the
GHCR image was pulled by the in-cluster runtime without credentials (packages are public) and the
rollout completed. The whole job took about 1m50s including teardown.

## Findings

- The kubeconfig step needs the same workaround as locally: Floci's EKS auth rejects `test/test`,
  so a real IAM user key is created in Floci first. Its secret is masked in the log.
- My first run failed only in teardown: `COMPOSE_FILE` is relative to the repo root and I ran
  `docker compose down` from the environment directory. Split into two steps, green on rerun.
- Not covered: multiple services talking to each other, or the frontend smoke check. Those are the
  next step, with the overlays.

## Verification

Two runs of the workflow on PR #7: the first passed every functional step and failed teardown, the
second passed fully.

## Next

Content-hash tags in `build.yml`, then the `deploy/` overlays and `deploy.yml`, which absorbs this
workflow's steps; the spike file is then deleted.
