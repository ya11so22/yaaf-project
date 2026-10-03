# Architecture Decision Records

Each decision is written down *before* it is built, with the options considered and why one was picked. Use
[`0000-template.md`](0000-template.md); number a new one after the highest ever used (0029). Numbers are never reused.

| ADR | Topic | Status |
|---|---|---|
| [0021](0021-project-purpose-scenario-and-scope.md) | Purpose, the retailer engagement, the vendored app, scope and finish line | accepted |
| [0022](0022-the-local-aws-environment.md) | The local AWS: Floci, the three OpenTofu roots, EKS, ingress, website hosting, operating it | accepted |
| [0023](0023-build-and-delivery.md) | CI on GitHub Actions, GHCR, content-hash tags, GitOps with Argo CD, rollback | accepted |
| [0024](0024-ci-cd-pipeline-standard.md) | The CI/CD pipeline standard: least privilege, provenance, digest pins, scan ratchet | accepted |
| [0025](0025-tool-versions-and-tasks-in-mise.md) | One `mise.toml` and lockfile for tool versions, shared values and tasks | accepted |
| [0026](0026-argo-cd-app-of-apps.md) | Argo CD Applications live in git (app-of-apps), in a least-privilege project | accepted |
| [0027](0027-arm64-only-app-images.md) | The app images are arm64 only, with explicit build arguments and an architecture check | accepted |
| [0028](0028-scenario-library.md) | Failure exercises become a library of spec-first scenarios | accepted |
| [0029](0029-gateway-api-for-ingress.md) | Gateway API instead of Ingress objects | accepted |
| [0005](0005-opentofu-over-terraform.md) | OpenTofu instead of Terraform | accepted |
| [0006](0006-github-oidc-role-design.md) | GitHub Actions to AWS through OIDC, three least-privilege roles | accepted |
| [0009](0009-local-pre-gate.md) | One pre-gate script shared by the git hook and CI | accepted |
| [0020](0020-zero-spend-real-aws-lane.md) | Real AWS only where it cannot cost money | rejected 2026-10-03 |

**History.** ADR-0001 to 0019 (other than 0005, 0006 and 0009) were superseded by 0021 to 0023 on 2026-09-24 and removed
from the tree on 2026-10-03. They record how decisions evolved (push-based CD to GitOps, the smee webhook relay built and
removed) and are readable at the tag `archive/windows-era`: `git show archive/windows-era:adr/archive/<file>`.
