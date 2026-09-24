# Architecture Decision Records

Each decision is written down *before* it is built, with the options considered and why one was picked
(`CONTRIBUTING.md`). Use [`0000-template.md`](0000-template.md) for a new one, numbered after the highest here or in
`archive/`. Numbers are never reused.

## Current decisions

Read these to know how the project works today.

| ADR | Topic | Status |
|---|---|---|
| [0021](0021-project-purpose-scenario-and-scope.md) | Purpose, the retailer engagement, the vendored app, scope and finish line | accepted |
| [0022](0022-the-local-aws-environment.md) | The local AWS: Floci, the three OpenTofu roots, EKS, ingress, website hosting, the up/down scripts | accepted |
| [0023](0023-build-and-delivery.md) | CI on GitHub Actions, GHCR, content-hash tags, GitOps with Argo CD, rollback | accepted |
| [0005](0005-opentofu-over-terraform.md) | OpenTofu instead of Terraform | accepted |
| [0006](0006-github-oidc-role-design.md) | GitHub Actions to AWS through OIDC, three least-privilege roles | accepted |
| [0009](0009-local-pre-gate.md) | One pre-gate script shared by the git hook and CI | accepted |
| [0020](0020-zero-spend-real-aws-lane.md) | Real AWS only where it cannot cost money | proposed |

## Archive

[`archive/`](archive/) keeps the sixteen earlier ADRs that the three consolidated ones replaced on 2026-09-24. They are
the record of how each decision evolved (for example, why push-based CD gave way to GitOps, or why the smee webhook
relay was built and later removed), which is useful for interviews. Each one's status line names its successor.

| Replaced by | Archived ADRs |
|---|---|
| 0021 | 0001 target app, 0010 market positioning, 0017 architecture track, 0018 scenario, 0019 scope cut |
| 0022 | 0002 emulation strategy, 0003 EKS over ECS, 0004 state backends, 0012 local first, 0014 operating the local AWS, 0016 ingress |
| 0023 | 0007 CI split and GHCR, 0008 phases and push-based CD, 0011 image identity, 0013 GitOps, 0015 smee webhook |
