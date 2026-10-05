# /infra

The local AWS and everything OpenTofu builds on it ([ADR-0022](../adr/0022-the-local-aws-environment.md)). Original
work for this project, not part of the vendored `/app`. OpenTofu, not Terraform: [ADR-0005](../adr/0005-opentofu-over-terraform.md).

The AWS here is [Floci](https://github.com/floci-io/floci), a free local emulator. Nothing in this folder can reach
real AWS: every provider uses Floci's endpoint and dummy keys (see the [cost guide](../docs/guides/aws-cost-safety.md)).

## Layout

```
infra/
├── environments/dev/
│   ├── compose.yaml    Floci, and floci-dash (the AWS-console-style dashboard, optional), pinned by digest, loopback only
│   ├── bootstrap/      1st root: the S3 bucket that holds the other roots' state (its own state is a local file)
│   ├── foundation/     2nd root: VPC, EKS, IAM, the ingress ALB, the portal website (state in S3)
│   ├── cluster/        3rd root: Argo CD, a project and the root Application; the rest is in deploy/apps (state in S3)
│   └── extras/         optional 4th root, `up --extras` only: a workstation to log in to (state in S3)
└── modules/
    ├── vpc/            VPC, public and private subnets over 2 AZs, internet gateway, one shared NAT gateway
    ├── eks-cluster/    EKS control plane, managed node group, cluster and node IAM roles
    ├── github-oidc/    GitHub OIDC provider and two least-privilege roles, plan and apply (ADR-0006)
    ├── alb-ingress/    an ALB forwarding to the ingress controller's NodePort
    ├── ec2-instance/   an instance with a security group, SSM instance profile and IMDSv2 only (the workstation, in the extras root)
    ├── static-site/    a private S3 bucket behind CloudFront with origin access control
    └── argocd/         Argo CD from its Helm chart, and its Applications
```

The roots are split by lifecycle, the way real teams layer infrastructure: the state bucket is created once, the
account-level infrastructure changes occasionally, and what runs in the cluster changes most. Each root is applied
after the one before it.

## Prerequisites and operating it

Colima (or another runtime) on a Mac, and [mise](https://mise.jdx.dev), which installs everything else at the versions in
[`mise.toml`](../mise.toml) (OpenTofu, `kubectl`, the AWS CLI, and the checkers). About 8 GB of memory for the project's own VM
while the cluster runs.

The environment is operated by four mise tasks (ADR-0025). Run them from the repository root:

| Task | What it does |
|---|---|
| `mise run up` | Starts the project's VM (`yaaf`) if it is stopped, then Floci, the three OpenTofu roots in order (bootstrap, foundation, cluster), the AWS profile and kubeconfig, a cluster repair if Floci left k3s dead, and Argo CD; then checks every URL. Idempotent. `--revision <branch>` tries a branch; `--plan-only` plans instead |
| `mise run up --extras` | The same, plus floci-dash and the `extras` root: a workstation to log in to, with its SSH key kept in `.ssh/` (gitignored) |
| `mise run down` | Stops Floci and the cluster gracefully, then the `yaaf` VM. Keeps all data |
| `mise run reset` | Deletes the `yaaf` VM and the local state files, after asking. Clean start |
| `mise run check` | The fast checks (`scripts/check`) |

The project runs in its **own** Colima VM, named `yaaf`, and never touches any other profile. `mise.toml` points Docker,
Colima, the AWS CLI and `kubectl` at the project (`COLIMA_PROFILE`, `DOCKER_CONTEXT`, and `.aws/` and `.kube/` in the
repository), so commands run here cannot reach other containers, your own `~/.aws` or `~/.kube`, or real AWS. What the tasks do,
in order, and the Floci quirks they work around, is in [`docs/mac-migration.md`](../docs/mac-migration.md). The manual
sequence, from inside `mise exec --`, is the same roots in turn:

```bash
docker compose -f infra/environments/dev/compose.yaml up -d --wait
tofu -chdir=infra/environments/dev/bootstrap init && tofu -chdir=infra/environments/dev/bootstrap apply
tofu -chdir=infra/environments/dev/foundation init && tofu -chdir=infra/environments/dev/foundation apply
# write the `floci` AWS CLI profile and kubeconfig (what `up` does after the foundation root), then:
tofu -chdir=infra/environments/dev/cluster init && tofu -chdir=infra/environments/dev/cluster apply -var kubeconfig_context=<cluster arn>
```

To reset, never use the runtime's "purge data" or `docker volume prune`: they delete Floci's data but leave the bootstrap
state behind. Use the `reset` task.

## What you can open

All on loopback: nothing is reachable from other machines. Use a regular browser (VS Code's built-in one shows
Headlamp as an empty page).

| URL | What |
|---|---|
| `http://<id>.cloudfront.localhost:4566/` | The portal: a static site in S3 behind CloudFront, linking to everything below: `http://$(tofu -chdir=infra/environments/dev/foundation output -raw portal_domain_name):4566/`. |
| http://localhost:9877 | floci-dash, a dashboard modelled on the AWS Management Console (only with `up --extras`) |
| http://argocd.localhost:18080 | Argo CD. User `admin`; the password is in the `argocd-initial-admin-secret` secret |
| http://headlamp.localhost:18080 | Headlamp, a read-only view of the cluster, no login |
| http://shop.localhost:18080 | The Online Boutique, through the ALB and Traefik |
| http://localhost:4566 | Floci's AWS API endpoint |

With `up --extras`, an EC2 **workstation** to log in to, three ways ([guide](../docs/guides/reaching-an-ec2-instance.md)): the terminal on
floci-dash's EC2 page, `ssh -i .ssh/floci-dev -p <port> root@127.0.0.1`, and `aws ssm send-command`. Floci publishes the SSH port
on all network interfaces; see the guide.

Browsers and `curl` resolve `*.localhost` names to loopback themselves.

## Using it like AWS

The `floci` profile points the AWS CLI at Floci, so ordinary commands work:

```bash
aws --profile floci s3 ls
aws --profile floci s3 cp .\notes.txt s3://my-bucket/          # after: aws --profile floci s3 mb s3://my-bucket
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

Objects created by hand (in floci-dash or with the CLI) are not in OpenTofu's state, and survive until a reset. That
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
- **CloudFront:** served over plain HTTP at `<id>.cloudfront.localhost:4566`, so the portal allows HTTP; on real
  AWS the module's default redirects to HTTPS.
- **EC2:** instances are Docker containers from minimal images, so there is no SSH server until user data installs one,
  login is `root`, and SSM Run Command works but Session Manager (`start-session`) does not. The SSH and security-group ports
  are published on all interfaces, a security group's source range is not enforced, and IMDSv2-required is not enforced.
- **Tags:** Floci drops tags on CloudFront distributions at creation and cannot read tags on IAM instance profiles, so the
  provider sees drift; the code works around each, with a comment
  ([upstream findings](../docs/research/2026-09-24-floci-upstream-findings.md)).
- **Restarts:** Floci restores the cluster only when the EKS API is first called. After an abrupt stop the k3s container can die
  on a stale IP while Floci still reports the cluster `ACTIVE`; and when Floci recreates the container, the new node registers under a
  new name and the old Node object stays `NotReady` forever. That is why the `up` task checks the cluster itself (API answering and
  one Ready node), removes ghost nodes, and rebuilds a cluster that is really dead.
- **State and resources together:** the OpenTofu state is in Floci's S3, so losing Floci's data loses the state
  with it. The next `up` rebuilds from code, which is the point.

## CI

`.github/workflows/infra.yml` checks formatting, validates all four roots, plans the foundation (on a local
backend, no Floci needed), and smoke-tests on a fresh Floci: bootstrap, apply the foundation on its S3 backend,
require a no-changes re-plan, apply the extras root and require it to be idempotent too, destroy both.
