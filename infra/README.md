# /infra

The local AWS and everything OpenTofu builds on it ([D22](../PLAN.md#d22)). Original
work for this project, not part of the vendored `/app`. OpenTofu, not Terraform: [D5](../PLAN.md#d5).

The AWS here is [Floci](https://github.com/floci-io/floci), a free local emulator. Nothing in this folder can reach
real AWS: every provider uses Floci's endpoint and dummy keys (see the [cost guide](../docs/guides/aws-cost-safety.md)).

## Layout

```
infra/
├── environments/dev/
│   ├── compose.yaml    Floci, pinned by digest, keeping nothing (memory only), loopback only
│   ├── bootstrap/      1st root: the S3 bucket that holds the other roots' state (its own state is a local file)
│   ├── foundation/     2nd root: VPC, EKS, ECR, IAM, the ingress ALB (state in S3)
│   └── cluster/        3rd root: Argo CD and the Applications it reconciles from git (state in S3)
└── modules/
    ├── vpc/            VPC, public and private subnets over 2 AZs, internet gateway, one shared NAT gateway
    ├── eks-cluster/    EKS control plane, managed node group, cluster and node IAM roles
    ├── ecr/            one repository per app service, lifecycle policy, immutable tags
    ├── github-oidc/    GitHub OIDC provider and three least-privilege roles (D6)
    ├── alb-ingress/    an ALB forwarding to the ingress controller's NodePort
    └── argocd/         Argo CD from its Helm chart, and its Applications
```

The roots are split by lifecycle, the way real teams layer infrastructure: the state bucket is created once, the
account-level infrastructure changes occasionally, and what runs in the cluster changes most. Each root is applied
after the one before it.

## Operating it

It runs wherever there is a Docker engine and [mise](https://mise.jdx.dev): a Claude Code cloud session (the project's
workbench, PLAN.md D30) or a CI runner. In a cloud session the SessionStart hook (`.claude/hooks/session-start.sh`)
installs mise and every tool at the versions locked in [`mise.lock`](../mise.lock), and starts Docker. The cluster wants
about 8 GB of memory.

Three mise tasks, run from the repository root:

| Task | What it does |
|---|---|
| `mise run up` | Builds the environment from git: Floci, the three OpenTofu roots in order, the AWS profile and kubeconfig, Argo CD; then checks the shop and Argo CD (on a host that can run Kubernetes). On a healthy environment it re-applies in place; anything stale (a Floci that stopped, leftovers from an earlier run) is removed first and built again. If the cluster does not come up, it rebuilds once from nothing. `--revision <branch>` makes Argo CD track a branch; `--plan-only` plans instead; `--aws-only` stops after the AWS layer |
| `mise run down` | Removes everything: Floci, the containers it started, the local bootstrap state, `.aws` and `.kube` |
| `mise run check` | The fast checks (`scripts/check`) |

**The platform is disposable, the data is not** (PLAN.md D39, D42). Floci keeps its AWS, and the OpenTofu state in its S3
bucket, in memory only, so a stopped Floci is a lost environment, and that is fine: everything is code, and `up` measures
how long rebuilding takes. Orders and carts are the exception: they leave the environment as encrypted backups and come
back on the next `up` (stage 2b of the plan). Watch out: a cloud session's worker can restart under you, which stops
Docker and everything in it; just run `up` again.

**In a cloud session, `up` builds the AWS layer only** (PLAN.md D44). The session's kernel uses cgroup v1, which
Kubernetes 1.35+ refuses, so `up` detects it and stops after the foundation root; `mise run check` validates the manifests
offline, and the cluster, Argo CD and the shop are proved on the arm64 runner. On the session VM: AWS layer from nothing
in about 3 minutes, a re-run in place in about 30 s.

`mise.toml` points the AWS CLI and `kubectl` at `.aws/` and `.kube/` in the repository, so commands run here cannot reach
your own `~/.aws` or `~/.kube`, or real AWS. The Floci quirks the tasks work around are [below](#floci-quirks). The manual
sequence, from inside `mise exec --`, is the same three roots in turn:

```bash
docker compose -f infra/environments/dev/compose.yaml up -d --wait
tofu -chdir=infra/environments/dev/bootstrap init && tofu -chdir=infra/environments/dev/bootstrap apply
tofu -chdir=infra/environments/dev/foundation init && tofu -chdir=infra/environments/dev/foundation apply
# write the `floci` AWS CLI profile and kubeconfig (what `up` does after the foundation root), then:
tofu -chdir=infra/environments/dev/cluster init && tofu -chdir=infra/environments/dev/cluster apply -var kubeconfig_context=<cluster arn>
```

## Floci quirks

Behaviour of Floci 2.1.0 that the tasks and modules work around.

| | Quirk (Floci 2.1.0) | Handling |
|---|---|---|
| Q1 | After an abrupt stop the k3s container can come back on a stale IP and exit, while Floci still reports the cluster `ACTIVE`. | Floci keeps nothing, so `up` never resumes a stopped environment: it removes it and builds again. If a fresh cluster still does not become Ready, `up` rebuilds once more. |
| Q2 | The cluster's datastore volume `floci-eks-<name>` carries no `floci=true` label. | `down` removes it by name. |
| Q4 | Port 4566 answers HTTP 200 for unknown hosts (an S3 list). | URL checks look for page content. |
| Q7 | IAM is not enforced by default; IMDSv2-required is not enforced. | Documented; `scripts/drills/iam-trust.sh` shows enforcement mode. |

Q3, Q5 and Q6 were CloudFront and EC2 quirks; they went with the portal and the workstation (PLAN.md D40) and are kept in
the [upstream findings](../docs/research/2026-09-24-floci-upstream-findings.md).

## What you can open

From the machine running it (a cloud session has no browser for you, so use `curl` there; the public demo is stage 4 of
the plan, through the [tunnel](../docs/guides/cloudflare-tunnel-and-access.md)):

| URL | What |
|---|---|
| http://argocd.localhost:18080 | Argo CD. User `admin`; the password is in the `argocd-initial-admin-secret` secret |
| http://shop.localhost:18080 | The Online Boutique, through the ALB and Traefik |
| http://localhost:4566 | Floci's AWS API endpoint |

`curl` and browsers resolve `*.localhost` names to loopback themselves.

## Using it like AWS

The `floci` profile points the AWS CLI at Floci, so ordinary commands work:

```bash
aws --profile floci s3 ls
aws --profile floci s3 cp ./notes.txt s3://my-bucket/          # after: aws --profile floci s3 mb s3://my-bucket
aws --profile floci eks describe-cluster --name yaaf-dev
aws --profile floci ec2 describe-vpcs
kubectl get pods -A
```

To change infrastructure, edit the code and run the `up` task, or run OpenTofu in one root:

```bash
cd infra/environments/dev/foundation
tofu init        # connects to the S3 backend on Floci
tofu plan
tofu apply
```

Objects created by hand (with the CLI) are not in OpenTofu's state, and last until the environment does. That
is fine for experiments; anything that should last belongs in code.

## Known differences from real AWS

Floci proves that tested SDK and IaC scenarios work, not that AWS behaves the same way. The ones that matter here:

- **EKS:** one k3s node whatever the node group asks for. The Kubernetes version follows the pinned k3s image
  (`FLOCI_SERVICES_EKS_DEFAULT_IMAGE` in `compose.yaml`), not the requested version, so the two are kept in step
  by hand. EKS authentication needs a key that exists in Floci's IAM, not the dummy `test` pair.
- **IAM:** enforcement is off by default, so policies, and trust for tokens from outside, are stored but not enforced.
  With enforcement on, identity policies and permission boundaries are evaluated, and IRSA tokens that Floci signs itself
  get full trust checking; GitHub's tokens cannot be verified either way. `scripts/drills/iam-trust.sh` shows all of it
  ([guide](../docs/guides/iam-policies-and-trust.md)).
- **Load balancing:** target health stays `initial` although traffic flows, and there is no TLS on the ingress.
- **Restarts:** after an abrupt stop the k3s container can die on a stale IP while Floci still reports the cluster
  `ACTIVE` (Q1). With nothing persisted, `up` rebuilds instead of resuming.
- **State and resources together:** the OpenTofu state is in Floci's S3, so losing Floci's data loses the state
  with it. That is the design here (D39): the next `up` rebuilds from code.

## CI

`.github/workflows/infra.yml` checks formatting, validates all three roots, plans the foundation (on a local
backend, no Floci needed), and smoke-tests on a fresh Floci: bootstrap, apply the foundation on its S3 backend,
require a no-changes re-plan, destroy.
