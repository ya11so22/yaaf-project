# /infra

OpenTofu modules and environments for the platform's AWS infrastructure: original work for
this project (not part of the vendored `/app`). See [ADR-0005](../adr/0005-opentofu-over-terraform.md)
for why OpenTofu, not Terraform.

## Layout

```
infra/
├── modules/
│   ├── vpc/             VPC, public/private subnets over 2 AZs, IGW, one shared NAT gateway
│   ├── eks-cluster/     EKS control plane, managed node group, cluster and node IAM roles
│   ├── ecr/             One repository per app service, lifecycle policy, immutable tags
│   └── github-oidc/     GitHub OIDC provider and three least-privilege roles (ADR-0006)
└── environments/
    ├── floci/           the `dev` environment: pointed at local Floci
    └── aws-milestone/   the `milestone` environment: real AWS (not built yet)
```

Environments call the same modules; only the provider block and environment-specific variables
differ, so what is validated on real AWS is the same shape exercised against Floci
([ADR-0002](../adr/0002-aws-emulation-strategy.md)). Environment *names* (`dev`, `milestone`) and
the promotion path between them are defined in [ADR-0008](../adr/0008-phase-reslice-cd-and-team-model.md);
the directory names are unchanged.

The ECR module is kept as tested IaC but the pipelines push images to GHCR instead
([ADR-0007](../adr/0007-ci-split-ghcr-and-floci-scope.md)).

## Running against Floci

Start Floci (and its UI at `http://localhost:4500`) with the compose file next to the
environment:

```powershell
cd infra/environments/floci
docker compose up -d
```

`compose.yaml` sets three things you would otherwise trip over:

- **Persistent storage** (`FLOCI_STORAGE_MODE=persistent`, a named volume): IAM, ECR and resources
  survive restarts, so the OpenTofu state stays valid. CI still starts a fresh Floci.
- **The k3s image is pinned** to the module's Kubernetes version. Floci does no version mapping:
  it runs whatever image `FLOCI_SERVICES_EKS_DEFAULT_IMAGE` names and echoes the requested
  version back as metadata, so keep the tag in step with `kubernetes_version` in `modules/eks-cluster`.
- **ECR URIs use path style** (`localhost:4566/<account>/<region>/<repo>`), because Windows and
  Docker Desktop cannot resolve the default `*.localhost` hostnames.

Then, with Floci up (`http://localhost:4566` by default):

```bash
cd infra/environments/floci
tofu init
tofu plan
tofu apply
```

`tofu plan` needs no running Floci on a fresh state, which is how the pipeline plans without it.

## Using kubectl against the Floci cluster

Floci's EKS auth rejects the public `test`/`test` keys and only accepts a key that exists in its
IAM. Run this once (and again only if the `floci_floci-data` volume is deleted):

```powershell
cd infra/environments/floci
powershell -ExecutionPolicy Bypass -File .\kubectl-setup.ps1
kubectl get nodes
```

The script creates a `kubectl-dev` IAM user in Floci, stores its key in an AWS CLI profile named
`floci`, and merges a kubeconfig context that uses it. Other contexts are left alone; switch back
with `kubectl config use-context <name>`. After a Floci restart the old node lingers as
`NotReady`; delete it with `docker exec floci-eks-yaaf-floci kubectl delete node <old-name>`.

## Known Floci differences from real AWS

These are why the real-AWS milestone exists. Details are in `docs/journal/`.

- The Kubernetes version follows the pinned image, not the requested version.
- A node group of any size yields one k3s node.
- IAM web-identity trust conditions are not enforced (so ADR-0006's security property is unproven
  until real AWS).
- EKS auth needs a real IAM key rather than the dummy pair.

## Status

- Applied and verified against Floci: `vpc`, `eks-cluster`, `ecr`, `github-oidc`.
- CI: `.github/workflows/infra.yml` plans without Floci and smoke-tests an apply from scratch.
- `environments/aws-milestone`: not built yet (see its README).
