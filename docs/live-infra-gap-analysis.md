# How this compares to live infrastructure

An honest scorecard, reviewed 2026-09-20 (ADR-0008). The short version: the project mirrors how
infrastructure is **built and changed** (IaC, CI gates, least-privilege identity, decision
records) well, and how it is **run** (deploy, observe, operate) only partly. Some gaps are
deliberate; the rest are scheduled.

## Scorecard

| Area | Now | What live-grade looks like | Gap and plan |
|---|---|---|---|
| **Delivery** | CI builds, scans and pushes images to GHCR. Nothing deployed the images; the local cluster held only system namespaces. | Merge leads to deploy with a smoke check and a rollback path. | Largest gap. Phase 1 adds push-based CD with kustomize overlays (ADR-0008). Rollback is a redeploy of the previous digest. |
| **Environments** | `environments/floci` and a placeholder `aws-milestone`, unconnected. | dev / staging / prod with promotion. | Named `dev` and `milestone`; the same image digest is promoted. No production, on purpose. |
| **State** | Local OpenTofu state. | Remote, locked, per environment, encrypted. | Open for `aws-milestone` (ADR-0004 follow-up). Floci state is disposable by design. |
| **Cluster** | Minimal EKS module. No add-ons, IRSA, autoscaling, logging or secret encryption. Floci runs one k3s node whatever the node group says. | Managed add-ons, IRSA, autoscaling, control-plane logs, KMS envelope encryption. | Add what the real-AWS milestone needs; Floci cannot prove the rest (ADR-0002). |
| **Ingress, DNS, TLS** | None. The VPC has subnets and a NAT gateway only. | Load balancer, DNS, certificates. | Not planned for Phase 1. Revisit only if the milestone needs a reachable frontend. |
| **Observability** | None. | Metrics, logs, at least one alert. | Minimal stack plus one alert in Phase 2, together with DORA metrics. Tracing stays Phase 4. |
| **Security** | OIDC federation with three least-privilege roles (ADR-0006), SHA-pinned actions, report-only image scans, no secrets in history. | Also secrets management, image signing and SBOMs, admission policy, network policies. | Threat model in Phase 1. Policy-as-code in Phase 2. IAM trust conditions are unproven until the real-AWS milestone: Floci does not enforce them. |
| **Cost and operations** | Ephemeral by design (ADR-0003). Budget alarm not built yet. | Always-on service with SLOs, on-call, incident process. | Not a goal: this is deliberately not a live service. Budget alarm comes before any real AWS. Each phase ends with a failure exercise and postmortem in place of on-call experience. |
| **Team and access** | One GitHub identity for everyone; reviews cannot be required. CODEOWNERS records intent. | Separate identities, enforced reviews, scoped access. | Bot identity for agents, enforceable reviews and namespace RBAC in Phase 2. |

## What is intentionally not being done, and why

- **A permanent production environment.** It would cost money and prove little the milestone deploy
  does not. Real AWS is used briefly and torn down (ADR-0002, ADR-0003).
- **A traffic-serving public service.** No load, no users; the value here is the platform around
  the app, not operating it.
- **Full cluster hardening on an emulator.** Floci cannot demonstrate it; the milestone is where
  fidelity gaps get tested.

## How to read the gaps

Three kinds. **Scheduled**: in a phase with a milestone (CD, observability, RBAC). **Deliberate**:
excluded above, with a reason. **Unproven**: built, but only real AWS can confirm it (IAM trust
conditions, node group behaviour, real networking). The third kind is why the real-AWS milestone
is mandatory rather than optional.
