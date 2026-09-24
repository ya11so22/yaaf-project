# ADR-0014: Operating the long-lived AWS: restart policy and one reconcile command

**Status:** superseded by [ADR-0022](../0022-the-local-aws-environment.md) (consolidated 2026-09-24; kept as the record of how the decision evolved)
**Date:** 2026-09-21

## Context

ADR-0013 makes the local Floci a long-lived "AWS". The first attempt to use it after the machine had
restarted failed, and investigating it found:

- Floci, its UI and the registry container all had `restart=no` in `compose.yaml`, so nothing came
  back after a restart. The Floci image was also the floating `latest`.
- Floci restores its EKS cluster lazily: after a restart it recreates or adopts the k3s container
  only when something first calls the EKS API.
- After an abrupt stop the k3s container survives; Floci adopts and starts it, and k3s then exits
  by itself (exit code 0, no signal) with `failed to find interface with specified node ip`,
  because the container's IP changed. Floci keeps reporting the cluster `ACTIVE`, so OpenTofu sees
  no drift.
- When Floci is stopped gracefully it removes the k3s container and keeps its data volume. The
  recreated container reuses that volume, so the old node object survives as a ghost node.
- The kubeconfig points at a port that changes when the cluster container is recreated, and the
  IAM key used for `kubectl` was created and rotated by an imperative script.

Piecemeal commands did not fix this. It needs one owned procedure.

## Decision

1. **Docker keeps Floci alive.** `compose.yaml` sets `restart: unless-stopped` on Floci and its UI,
   and pins both images by digest (Floci v2.1.0). Docker Desktop must start at login (a setting on
   the owner's machine).
2. **`scripts/dev-up.ps1` is the single, idempotent way to bring the AWS up cleanly**, safe to run
   any number of times:
   1. wait for the Docker engine;
   2. `docker compose up -d --wait`, which waits on Floci's own health check;
   3. call the EKS API, which triggers Floci's lazy restore;
   4. if a cluster exists but its API is not ready, repair it: remove the k3s container and its data
      volume, restart Floci so it recreates the cluster from scratch, and wait for the API;
   5. `tofu apply` on `infra/environments/floci`, which reconciles everything OpenTofu owns (VPC,
      EKS, ECR, IAM, and Argo CD when it lands) and is the drift detection;
   6. refresh the kubeconfig and require every node to be Ready.
   It fails loudly, with the k3s log, if the cluster is still not healthy.
3. **k3s state is disposable.** The cluster's datastore is not treated as data. Workloads are
   restored by Argo CD from git (ADR-0013); the repair path is only safe because of that.
4. **The `kubectl` IAM user and key are OpenTofu resources**, not created by a script, and the
   script reads them from the outputs. `kubectl-setup.ps1` is removed.
5. **Automatic at login.** `dev-up.ps1 -Register` creates a per-user Windows scheduled task that runs
   it at logon and logs to `%LOCALAPPDATA%\yaaf\dev-up.log`. After a restart nothing else is needed.
6. Health of the k3s container is checked by the script because OpenTofu cannot see it: Floci
   reports `ACTIVE` regardless.
7. **`scripts/dev-down.ps1` is the safe shutdown.** It backs up the two OpenTofu state files (gitignored, so not
   on GitHub, and needed: without them OpenTofu would try to create what already exists), stops Floci
   gracefully and then anything it started, and removes nothing. A graceful stop is the recoverable path;
   an abrupt one is what left the cluster with a stale IP. Reset or prune commands that delete the Docker
   volumes are the only things that lose state.

## Options considered

- **Keep running commands by hand after each restart:** what failed. Rejected.
- **Only add `restart: unless-stopped`:** brings Floci back but not the cluster, which needs the EKS
  poke and, after an abrupt stop, the repair. Necessary, not sufficient.
- **Wipe and recreate the cluster on every login:** simplest and always clean, but discards a
  healthy cluster and its pods for no reason. The health check keeps the wipe for when it is needed.
- **A background service or a compose sidecar that runs the reconcile:** more moving parts than a
  logon task for a single-user local setup.
- **Fix Floci upstream:** the adoption failure (and the cluster reporting ACTIVE with a dead
  container) are reportable issues, and would satisfy the standing external-contribution goal, but
  the project cannot depend on a fix landing.

## Consequences / trade-offs accepted

- Running `tofu apply` unattended at login is acceptable because the target is a local emulator
  with local state. It would not be for real AWS.
- The repair path deletes cluster state. Until Argo CD exists, anything deployed by hand to the
  cluster is lost on repair.
- The logon task depends on Docker Desktop starting at login; the script waits up to five minutes
  for the engine rather than failing at once.
- The Floci-managed registry container is not under Docker's restart policy either. Floci starts it
  when ECR is used; a stale registry container is a possible further failure to watch for.
