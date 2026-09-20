# /infra

OpenTofu modules and environments for the platform's AWS infrastructure — original work for
this project (not part of the vendored `/app`). See [ADR-0005](../adr/0005-opentofu-over-terraform.md)
for why OpenTofu, not Terraform.

## Layout

```
infra/
├── modules/
│   └── vpc/              ← reusable VPC module (this is the only module so far)
└── environments/
    ├── floci/             ← root config pointed at local Floci (day-to-day loop)
    └── aws-milestone/      ← not built yet; real-AWS validation runs (ADR-0002/0003)
```

Environments call the same modules; only the provider block and environment-specific variables
differ between `floci` and `aws-milestone`, so what gets validated against real AWS is the same
OpenTofu shape exercised locally, not a parallel definition.

## Running against Floci

Start Floci (and its UI at `http://localhost:4500`) with the compose file next to the
environment:

```powershell
cd infra/environments/floci
docker compose up -d
```

`compose.yaml` pins Floci's k3s image via `FLOCI_SERVICES_EKS_DEFAULT_IMAGE`. Floci does no
version mapping: it runs whatever image that names (default `rancher/k3s:latest`) and echoes
the requested version back as metadata, so keep the tag in step with `kubernetes_version` in
`modules/eks-cluster`.

Then, with Floci up (`http://localhost:4566` by default):

```bash
cd infra/environments/floci
tofu init
tofu plan
tofu apply
```

## Status

- `modules/vpc`: VPC, public/private subnets across 2 AZs, IGW, single shared NAT gateway.
  Applied and verified against Floci (2026-09-20).
- Next up: `eks-cluster` and `ecr` modules, then `iam`, per the Phase 1 roadmap in the root
  README.
- `environments/aws-milestone`: intentionally empty until Phase 1 reaches its real-AWS
  validation milestone (AWS Budgets/billing alarm land here first, per the cost guardrail).
