# /platform

Platform-layer tooling and docs for Phase 2 ([ADR-0008](../adr/0008-phase-reslice-cd-and-team-model.md)):

- **GitOps and per-PR environments:** Argo CD in a persistent cluster, a namespace per PR created
  on open and torn down on close or when idle.
- **Team access model:** a bot identity for the agent app team, enforceable required reviews, and
  a namespace with RBAC per team so agents can only touch their own workloads.
- **Stretch:** a minimal service catalog page rather than running Backstage full-time.

Empty until Phase 2 starts.
