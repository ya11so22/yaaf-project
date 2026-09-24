# ADR-0022: The local AWS environment

**Status:** accepted (consolidates and supersedes ADR-0002, 0003, 0004, 0012, 0014 and 0016, now in
[`archive/`](archive/); real AWS is covered by [ADR-0020](0020-zero-spend-real-aws-lane.md))
**Date:** 2026-09-24

## Context

The project needs an AWS to build on and learn with, at no cost and with no risk of a bill (ADR-0020). Since
2026-08-22 that has been Floci, a free, MIT-licensed local AWS emulator, and six ADRs shaped how it is used:
emulation strategy (0002), EKS over ECS (0003), state (0004), local first (0012), how it is operated (0014) and
ingress (0016). On 2026-09-24 the owner asked for a clean reset: current tools, clean start and stop scripts, an
AWS-console-style dashboard, and a setup that can run infrastructure as code, storage, EKS and website hosting
the way real AWS does. This ADR states the environment as it now is.

## Options considered

- **Emulator:** Floci (chosen: free, no account, broad coverage including EKS on k3s, ELBv2, S3 website hosting and
  CloudFront delivery); LocalStack (needs an account and token since March 2026, free for non-commercial use only,
  EKS in the paid tier); moto (a test library, not a running cloud).
- **Compute:** EKS (chosen: the Kubernetes story the target roles ask about; Floci runs it on k3s); ECS Fargate
  (simpler, but a shallower story).
- **State:** local files (what this replaces: easy to lose, and out of step with Floci when either is reset); S3 on
  Floci with native locking (chosen: how real teams hold state); a SaaS backend (HCP Terraform cannot run OpenTofu
  or reach localhost).
- **Dashboard:** floci-ui (Floci's own, simpler); **floci-dash** (chosen: modelled on the AWS Management Console
  with AWS's Cloudscape design system, so what the owner learns carries over to the real console).

## Decision

1. **Floci is the AWS**, long-lived on the owner's machine, pinned by digest (2.1.0) with persistent storage, in
   `infra/environments/dev/compose.yaml`. "AWS" in the docs means this layer; **dev** is the only environment.
   Nothing billable is ever created on real AWS (ADR-0020).
2. **Everything is on loopback.** Floci (`127.0.0.1:4566`), the ingress listener (`127.0.0.1:8080`) and the
   dashboard (`127.0.0.1:9877`) are published on `127.0.0.1` only. Floci holds the Docker socket, so exposing it
   on the network would let anyone who can reach the machine start containers on it.
3. **floci-dash** (MIT, v0.4.0, pinned by digest) replaces floci-ui, **with the Docker socket**, so its in-browser
   EC2 terminal works as intended. First built without it; the owner chose on 2026-09-24 to use the dashboard fully.
   The terminal only execs into `floci-ec2-<instance-id>` containers, but any process holding the socket controls
   Docker on the machine, so floci-dash is trusted at its pinned digest and reviewed before each bump. SSH with an
   imported key pair and SSM Run Command, both supported by Floci, remain the AWS-realistic ways into an instance.
4. **Three OpenTofu roots, applied in order**, under `infra/environments/dev/`:
   | Root | Holds | State |
   |---|---|---|
   | `bootstrap` | The state bucket: versioned, encrypted, public access blocked | Local file (the bucket cannot hold its own creator's state) |
   | `foundation` | The account-level infrastructure: VPC, EKS, ECR, IAM (the `kubectl` user, the GitHub OIDC roles of ADR-0006), the ingress ALB, the static website | S3 on Floci, S3 lock file |
   | `cluster` | What runs inside EKS: Argo CD and its Applications (ADR-0023) | S3 on Floci, S3 lock file |
   A separate `cluster` root is needed because the Helm provider must connect to a cluster that already exists.
   State lives in the same Floci as the resources, so resetting one resets both and they never disagree.
5. **EKS** is Floci's k3s, pinned to `rancher/k3s:v1.36.4-k3s1` to match the module's Kubernetes 1.36, the newest
   version EKS supports (Floci does no version mapping, so the two are kept in step by hand). Floci runs one node
   whatever the node group asks for.
6. **Ingress:** browser → `http://<name>.localhost:8080` → a Floci ALB (`preserve_host_header` on) → Traefik's
   NodePort on the k3s node → Ingress rules by host. Traefik is installed by Argo CD.
7. **Website hosting, the AWS way:** a private S3 bucket behind a CloudFront distribution with origin access
   control, the pattern AWS recommends for static sites. Floci serves it at `http://<id>.cloudfront.localhost:4566/`.
   The first site is a small portal that links to every local endpoint.
8. **An EC2 workstation** (`modules/ec2-instance`, Amazon Linux 2023) is created in the foundation root to practise the
   three ways into an instance, as AWS offers them: the terminal in floci-dash's EC2 page, SSH from the owner's own
   terminal, and SSM Run Command. `dev-up` creates a dedicated key `~/.ssh/floci-dev` once and passes only its public half to
   OpenTofu, which imports it as a key pair; user data installs `sshd` because Floci's instance images have none; the
   instance has an SSM instance profile and requires IMDSv2. The security group allows SSH from `127.0.0.1/32` only, which
   Floci does not enforce. Session Manager's interactive shell is unsupported by Floci 2.1.0 and is not part of this.
   The guide is `docs/guides/reaching-an-ec2-instance.md`.
9. **Two scripts operate it**, both idempotent and tested on PowerShell 7 and Windows PowerShell 5.1:
   - `scripts/dev-up.ps1` starts Docker Desktop if needed, starts Floci and the dashboard, applies the three roots
     in order, checks the cluster (and repairs it if Floci left it broken: the k3s state is disposable, since Argo
     CD restores workloads from git), writes an AWS CLI profile `floci`, and prints every URL.
   - `scripts/dev-down.ps1` stops everything gracefully and keeps all data. `-Reset` deletes everything (Floci's
     data, the cluster, the state) after a confirmation, for a clean start. `-QuitDocker` also quits Docker Desktop.
   The old "run at every login" option is dropped: the owner starts the environment when they want it.
10. **CI uses a fresh Floci per run** with the same compose file, and swaps in a local backend with an override file,
   so a pull request never touches the owner's environment.

## Rationale

Real AWS is ruled out by cost risk, so the emulator has to be as close to real practice as it can be: state in S3
with locking, a bootstrap root for the state bucket, the console-style dashboard, S3 and CloudFront for websites,
an ALB for ingress. Where Floci differs from AWS, the difference is written down (in `infra/README.md` and the
guides) rather than hidden. Splitting the roots by lifecycle (state, account, cluster) is the layering real teams
use, and makes each root's job obvious. Loopback binding removes the network exposure of running an emulator on a personal
machine; the dashboard's socket access is a known, accepted trade-off for a working console.

## Consequences / trade-offs accepted

- Floci proves that tested SDK and IaC scenarios work, not that AWS behaves identically. IAM enforcement is off by
  default (`scripts/drills/iam-trust.sh` shows what it does when on), it runs one EKS node, reports load balancer target health as `initial`, and has no TLS on the
  ingress. These are listed in `infra/README.md`.
- If Floci's data volume is lost, the state goes with it; the next `dev-up` recreates everything from code. Only
  the tiny bootstrap state is a local file.
- floci-dash is a young third-party project (51 stars at pinning time) holding the Docker socket. It is pinned by
  digest and bumped only after reading its changes. Its terminal WebSocket does not check the page's origin, so a
  malicious site open in the same browser could try to open a shell into an EC2 instance (not the host) if it knew the
  instance ID; reported as an upstream candidate.
- Floci publishes the workstation's SSH port, and any port a security group opens, on all network interfaces, with no
  bind-address setting and no enforcement of the source range. Login needs the key, so the SSH port is not an open door, but
  it is reachable from the local network. The guide gives a Windows Firewall rule that blocks network access and keeps
  local access; it needs administrator rights and is left to the owner to apply. Reported upstream as a draft
  (`docs/research/2026-09-24-floci-upstream-findings.md`).
- Floci's own dashboard and the "run at login" task are gone; both can come back from git history if wanted.
- The reset path and the bump of the dashboard or Floci are manual, deliberate steps.
