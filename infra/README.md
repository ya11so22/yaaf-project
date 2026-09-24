# /infra

The local AWS and everything OpenTofu builds on it ([ADR-0022](../adr/0022-the-local-aws-environment.md)). Original
work for this project, not part of the vendored `/app`. OpenTofu, not Terraform: [ADR-0005](../adr/0005-opentofu-over-terraform.md).

The AWS here is [Floci](https://github.com/floci-io/floci), a free local emulator. Nothing in this folder can reach
real AWS: every provider uses Floci's endpoint and dummy keys (see the [cost guide](../docs/guides/aws-cost-safety.md)).

## Layout

```
infra/
├── environments/dev/
│   ├── compose.yaml    Floci and floci-dash (the AWS-console-style dashboard), pinned by digest, loopback only
│   ├── bootstrap/      1st root: the S3 bucket that holds the other roots' state (its own state is a local file)
│   ├── foundation/     2nd root: VPC, EKS, ECR, IAM, the ingress ALB, the portal website (state in S3)
│   └── cluster/        3rd root: Argo CD and the Applications it reconciles from git (state in S3)
└── modules/
    ├── vpc/            VPC, public and private subnets over 2 AZs, internet gateway, one shared NAT gateway
    ├── eks-cluster/    EKS control plane, managed node group, cluster and node IAM roles
    ├── ecr/            one repository per app service, lifecycle policy, immutable tags
    ├── github-oidc/    GitHub OIDC provider and three least-privilege roles (ADR-0006)
    ├── alb-ingress/    an ALB forwarding to the ingress controller's NodePort
    ├── ec2-instance/   an instance with a security group, SSM instance profile and IMDSv2 only (the workstation)
    ├── static-site/    a private S3 bucket behind CloudFront with origin access control
    └── argocd/         Argo CD from its Helm chart, and its Applications
```

The roots are split by lifecycle, the way real teams layer infrastructure: the state bucket is created once, the
account-level infrastructure changes occasionally, and what runs in the cluster changes most. Each root is applied
after the one before it.

## Prerequisites

Docker Desktop, [OpenTofu](https://opentofu.org/docs/intro/install/) 1.10 or later, the AWS CLI v2, `kubectl` and
`curl` (built into Windows), and the Windows OpenSSH client for `ssh` and `ssh-keygen` (an optional Windows feature). About 6 GB of free memory for Docker while the cluster runs.

## Start and stop

```powershell
.\scripts\dev-up.ps1        # start or repair everything; safe to run any number of times
.\scripts\dev-down.ps1      # stop everything, keep all data
```

`dev-up.ps1` starts Docker Desktop if needed, then Floci and floci-dash, applies the three roots in order, writes the
`floci` AWS CLI profile and the kubeconfig, checks the cluster (and repairs it if Floci left it broken), waits for
Argo CD and checks every URL. A first run takes several minutes; later runs mostly report "No changes". Its log is
`%LOCALAPPDATA%\yaaf\dev-up.log`.

| Option | Does |
|---|---|
| `dev-up.ps1 -Revision <branch>` | Argo CD tracks a branch, to try a change before merging. Run plain `dev-up` again once it is merged. |
| `dev-up.ps1 -PlanOnly` | Plans instead of applying. |
| `dev-down.ps1 -QuitDocker` | Also quits Docker Desktop, to give its memory back. |
| `dev-down.ps1 -Reset` | Deletes everything (Floci's data, the state, the cluster) after a confirmation, for a clean start. `-Force` skips the question; `-WhatIf` shows what would happen. |

Both scripts back up the state first, to `$HOME\yaaf-backup\<timestamp>` (the newest five are kept).

Do not use Docker Desktop's "Clean / Purge data" or `docker volume prune` to reset: they delete Floci's data but
leave the bootstrap state behind. Use `dev-down.ps1 -Reset`.

## What you can open

All on loopback: nothing is reachable from other machines. Use a regular browser (VS Code's built-in one shows
Headlamp as an empty page).

| URL | What |
|---|---|
| `http://<id>.cloudfront.localhost:4566/` | The portal: a static site in S3 behind CloudFront, linking to everything below. `dev-up` prints the exact URL. |
| http://localhost:9877 | floci-dash, a dashboard modelled on the AWS Management Console |
| http://argocd.localhost:8080 | Argo CD. User `admin`; the password is in the `argocd-initial-admin-secret` secret |
| http://headlamp.localhost:8080 | Headlamp, a read-only view of the cluster, no login |
| http://shop.localhost:8080 | The Online Boutique, through the ALB and Traefik |
| http://localhost:4566 | Floci's AWS API endpoint |

And an EC2 **workstation** to log in to, three ways ([guide](../docs/guides/reaching-an-ec2-instance.md)): the terminal on
floci-dash's EC2 page, `ssh -i ~/.ssh/floci-dev -p <port> root@127.0.0.1`, and `aws ssm send-command`. `dev-up` prints the
exact commands. Floci publishes the SSH port on all network interfaces; the guide has the firewall command that closes that.

Browsers resolve `*.localhost` names to loopback themselves; command-line tools on Windows may not, so use
`curl.exe -H "Host: shop.localhost" http://127.0.0.1:8080/`.

## Using it like AWS

The `floci` profile points the AWS CLI at Floci, so ordinary commands work:

```powershell
aws --profile floci s3 ls
aws --profile floci s3 cp .\notes.txt s3://my-bucket/          # after: aws --profile floci s3 mb s3://my-bucket
aws --profile floci eks describe-cluster --name yaaf-dev
aws --profile floci ec2 describe-vpcs
kubectl get pods -A
```

To change infrastructure, edit the code and run `dev-up.ps1`, or run OpenTofu in one root:

```powershell
cd infra\environments\dev\foundation
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
- **Restarts:** Floci restores the cluster only when the EKS API is first called, and after an abrupt stop the k3s
  container can die on a stale IP while Floci still reports the cluster `ACTIVE`. That is why `dev-up.ps1` checks the
  cluster itself and repairs it.
- **State and resources together:** the OpenTofu state is in Floci's S3, so losing Floci's data loses the state
  with it. The next `dev-up` rebuilds from code, which is the point.

## CI

`.github/workflows/infra.yml` checks formatting, validates all three roots, plans the foundation (on a local
backend, no Floci needed), and smoke-tests on a fresh Floci: bootstrap, apply the foundation on its S3 backend,
require a no-changes re-plan, destroy.
