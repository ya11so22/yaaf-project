# /infra

Terraform modules and environments for the platform's AWS infrastructure — original work for
this project (not part of the vendored `/app`).

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
Terraform shape exercised locally, not a parallel definition.

## Running against Floci

With Floci up locally (`http://localhost:4566` by default):

```bash
cd infra/environments/floci
terraform init
terraform plan
terraform apply
```

## Status

- `modules/vpc`: VPC, public/private subnets across 2 AZs, IGW, single shared NAT gateway.
- Next up: `eks-cluster` and `ecr` modules, then `iam`, per the Phase 1 roadmap in the root
  README.
- `environments/aws-milestone`: intentionally empty until Phase 1 reaches its real-AWS
  validation milestone (AWS Budgets/billing alarm land here first, per the cost guardrail).
