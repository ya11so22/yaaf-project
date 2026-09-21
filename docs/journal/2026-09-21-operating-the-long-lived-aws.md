# 2026-09-21: Operating the long-lived AWS after a restart

**Phase:** Phase 1, continuous delivery (operations of the base)
**Related ADRs:** [ADR-0014](../../adr/0014-operating-the-long-lived-aws.md), [ADR-0013](../../adr/0013-gitops-with-argo-cd-on-long-lived-aws.md)

## What happened

The GitHub App secrets were set (`BOT_APP_ID`, `BOT_APP_PRIVATE_KEY`). Starting the `argocd` module
meant using the long-lived Floci, which had not survived the machine's restart, and a first round
of manual commands made things worse rather than better. Investigation found four separate causes:

1. `compose.yaml` had no restart policy (`restart=no` on Floci, its UI and the registry), and the
   image was the floating `latest`. Nothing came back after a restart.
2. Floci restores its EKS cluster only when the EKS API is first called after a restart.
3. After an abrupt stop the surviving k3s container is adopted and started, then exits by itself
   (code 0, no signal) with `failed to find interface with specified node ip`, because its IP
   changed. Floci keeps reporting `ACTIVE`, so OpenTofu sees no drift.
4. After a graceful stop Floci removes the container but keeps its data volume; the recreated
   container reuses it, so the old node stays behind as a `NotReady` ghost. The API port also
   changes (6500, 6501), which stales the kubeconfig.

The owner asked for one finalised solution instead of back-and-forth commands. ADR-0014 records it:
compose restart policy and pinned images; `scripts/dev-up.ps1` as the single idempotent
command (Docker, Floci health, `tofu apply`, kubeconfig, cluster health with a wipe-and-recreate
repair); the `kubectl` IAM user and key as OpenTofu resources instead of a rotating script; and
`-Register` to run it at login. `kubectl-setup.ps1` was removed.

## Why

See ADR-0014. The key point: OpenTofu cannot see a dead k3s container, so the script must check the
cluster itself, and the repair is only safe because k3s state is disposable (workloads come from git).

## Verification

- The script parses and runs under Windows PowerShell 5.1 and PowerShell 7.6; `-PlanOnly` starts
  Floci, waits for health, and `tofu plan` reports `2 to add, 0 to change, 0 to destroy`: only the
  new IAM user and key, no drift on the cluster.
- The repair path was run on both shells: the k3s container and volume were removed, Floci
  restarted, and the cluster came back Ready with a single node, no ghost, in about 19 seconds.
- Not yet run: the full `tofu apply` path (an automated apply is blocked for me) and a real machine
  restart. The owner runs `.\scripts\dev-up.ps1` once and then a reboot.

## Next

Confirm the full run and a reboot, then the `argocd` OpenTofu module, and after that the committed
image pins with the bump workflow. The two Floci behaviours (cluster reported `ACTIVE` with a dead
container; adoption failing on a changed IP) are candidates for the upstream contribution goal.
