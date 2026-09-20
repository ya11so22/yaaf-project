# 2026-09-20: EKS-equivalent cluster module, wired into the Floci environment

**Phase:** Phase 1 — AWS IaC + GitHub Actions foundation
**Related ADRs:** [ADR-0003](../../adr/0003-eks-ephemeral-vs-ecs-fargate.md), [ADR-0002](../../adr/0002-aws-emulation-strategy.md)

## What happened

Added `infra/modules/eks-cluster`: an EKS control plane, a managed node group (default
`t3.medium`, 1-3 nodes, desired 2), and the two IAM roles they need (cluster role, node role,
with the standard AWS-managed policy attachments). Instantiated it in `environments/floci` on
the VPC module's private subnets, with `cluster_name`/`cluster_endpoint` outputs.

The IAM roles live inside this module for now rather than waiting for the separate IAM module
on the roadmap: EKS can't be created without them, and the IAM module's scope (OIDC federation
for GitHub Actions, later IRSA) is different. Revisit if the roles need to be shared.

## Why

ADR-0003 already covers the EKS-over-Fargate decision; nothing new needed an ADR.

## Verification

`tofu fmt -recursive`, `tofu validate` ("configuration is valid"), and `tofu plan` against the
live Floci instance: `Plan: 8 to add, 0 to change, 0 to destroy` (2 IAM roles, 4 policy
attachments, cluster, node group). The user then ran `tofu apply` and it came back clean;
`tofu plan` afterwards shows no drift.

### kubectl reachability

Verified `kubectl` reaches the Floci-backed cluster from the host, using a throwaway kubeconfig
(`aws eks update-kubeconfig --kubeconfig <scratch file>`) so the user's existing default kubectl context
was never touched (its default context is `rancher-desktop`). `kubectl get nodes` shows one `Ready` control-plane node; `kube-system` has
coredns, local-path-provisioner and metrics-server running; `kubectl auth whoami` returns
`floci:aws-iam` in `system:masters`.

Findings (Floci behaviour worth remembering, and interview-relevant fidelity gaps per ADR-0002):

- **Auth rejects the `test`/`test` keys.** Floci's IAM-auth webhook deliberately refuses the
  public dummy credential pairs for EKS tokens, so `kubectl` returned `Unauthorized` until a real
  IAM user + access key was created in Floci (`aws iam create-user` / `create-access-key`) and
  exported for `aws eks get-token`. That user was created by hand, not by OpenTofu, and lives
  only in the disposable emulator. Keys are not recorded in the repo.
- **The k3s version doesn't follow the requested one.** The module asks for Kubernetes `1.31`
  (and `describe-cluster` reports 1.31), but the node runs k3s `v1.34.1`.
- **The node group is not emulated as N nodes.** Desired size 2 still yields a single k3s node
  (named by container ID, role `control-plane`); `list-nodegroups` does report
  `yaaf-floci-default`.
- On Git Bash for Windows, `docker exec ... /etc/...` paths get rewritten; set
  `MSYS_NO_PATHCONV=1`.

## Next

- Then the ECR-equivalent registry module, then IAM.
