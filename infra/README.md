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

## Bringing the local AWS up: `scripts/dev-up.ps1`

One idempotent command owns the local Floci lifecycle (ADR-0014). Run it after a restart, after
changing the infrastructure, or whenever something looks wrong:

```powershell
.\scripts\dev-up.ps1
```

It waits for Docker, starts Floci and waits for its health check, runs `tofu apply` on this
environment (which is the drift detection), refreshes the kubeconfig and requires the cluster API
and every node to be Ready. If the cluster is not healthy it wipes the k3s container and volume,
lets Floci recreate the cluster, and applies again. k3s state is disposable; workloads come back
from git. `-PlanOnly` runs `tofu plan` instead of apply.

To run it automatically at every login (per user, no admin), once:

```powershell
.\scripts\dev-up.ps1 -Register      # -Unregister removes it; the log is %LOCALAPPDATA%\yaaf\dev-up.log
```

Docker Desktop must start at login (Docker Desktop settings). Compose gives Floci
`restart: unless-stopped`, so Docker brings the emulator back by itself.

After the cluster is ready, `dev-up.ps1` also applies `environments/floci-cluster`, which installs
Argo CD and an Application for `deploy/dev`. It tracks `main` by default; to try a change before it
is merged, run `.\scripts\dev-up.ps1 -Revision <branch>`. Argo CD's UI is reached with
`kubectl -n argocd port-forward svc/argocd-server 8080:80`.

`kubectl` authenticates as an IAM user that OpenTofu creates in Floci (Floci's EKS auth rejects the
public `test`/`test` keys and only accepts a key that exists in its IAM); `dev-up.ps1` reads that key
from the OpenTofu outputs into an AWS CLI profile named `floci` and merges the kubeconfig context.
Other contexts are left alone; switch back with `kubectl config use-context <name>`.

## Known Floci differences from real AWS

These are why the real-AWS milestone exists. Details are in `docs/journal/`.

- The Kubernetes version follows the pinned image, not the requested version.
- A node group of any size yields one k3s node.
- IAM web-identity trust conditions are not enforced (so ADR-0006's security property is unproven
  until real AWS).
- EKS auth needs a real IAM key rather than the dummy pair.
- Floci restores its EKS cluster lazily, only when the EKS API is first called after a restart.
- After an abrupt stop, the surviving k3s container is adopted and can exit at once because its
  IP changed, while Floci keeps reporting the cluster `ACTIVE`. OpenTofu cannot see this, which is
  why `dev-up.ps1` checks the cluster itself.
- After a graceful stop the k3s container is removed but its data volume is kept and reused, so
  the old node lingers as a `NotReady` ghost.

## Status

- Applied and verified against Floci: `vpc`, `eks-cluster`, `ecr`, `github-oidc`.
- CI: `.github/workflows/infra.yml` plans without Floci and smoke-tests an apply from scratch.
- `environments/aws-milestone`: not built yet (see its README).
