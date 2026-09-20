# /policy

Policy-as-code guardrails for Phase 2: OPA/`conftest` checks run in CI against OpenTofu plans and
Kubernetes manifests, so guardrails do not need an always-on admission controller. First rules:

- No IAM trust policy may use a wildcard OIDC `sub` (ADR-0006 notes Floci cannot enforce trust,
  so the check has to happen on the plan).
- Required tags on resources; basic manifest linting for the deploy overlays.

Empty until Phase 2 starts.
