# Guide: The local AWS environment

**Related:** [ADR-0022](../../adr/0022-the-local-aws-environment.md), [`infra/README.md`](../../infra/README.md),
[journal](../journal/2026-09-24-reset-and-local-aws-rebuild.md)
**Evidence:** verified on Floci (built from nothing, re-applied with no changes, every endpoint checked, 2026-09-24)

## The idea

An **emulator** answers the same API calls as AWS, on your own machine, for free. Your tools (the AWS CLI, OpenTofu,
SDKs) do not know the difference: you point them at `http://localhost:4566` instead of `amazonaws.com`. Some services
are only records (IAM stores policies but does not enforce them); others really run (EKS starts a real Kubernetes, S3
stores real files, CloudFront serves real pages). Knowing which is which is most of the skill of using one.

## How it works here

```
Docker Desktop
├── floci        the AWS API on 127.0.0.1:4566 (and the ALB listener on 127.0.0.1:8080)
│   └── starts, when asked:  floci-eks-yaaf-dev (k3s: the EKS cluster)  ·  floci-ecr-registry (ECR)
└── floci-dash   an AWS-console-style dashboard on 127.0.0.1:9877
```

OpenTofu builds on it in three **roots**, each with its own state, applied in order by `scripts/dev-up.ps1`:

1. **bootstrap** creates one S3 bucket, `yaaf-dev-tfstate`: versioned, encrypted, public access blocked, and
   protected from deletion. Its own state is a local file, because a bucket cannot store the state of the code that
   creates it.
2. **foundation** holds the account-level infrastructure: VPC, EKS, ECR, IAM, the ALB, and the portal site. Its state
   is `foundation/terraform.tfstate` in that bucket.
3. **cluster** installs Argo CD into EKS, which then deploys everything else from git. State: `cluster/terraform.tfstate`.

The portal is a **static website done the AWS way**: a private bucket that nobody can read directly, a CloudFront
distribution in front of it, and an *origin access control* that lets only that distribution read the bucket. The
bucket policy names the distribution's ARN, so no other distribution (in any account) can use the bucket.

## Why this way

- **State in S3 with locking** is how teams share state: everyone reads the same file, and a lock object
  (`terraform.tfstate.tflock`, written with an S3 conditional write) stops two applies running at once. Before
  this, the state was a local file that could disagree with Floci after a reset.
- **Layered roots** separate things that change at different speeds. A mistake in the cluster root cannot touch the
  state bucket.
- **floci-dash** looks like the AWS console, so clicking around here is practice for the real one.
- **Loopback only**: Floci holds the Docker socket, so exposing it on the network would let anyone on the network
  start containers on your machine.

## Watch out for

- **Emulator bugs look like your bugs.** Two were found while building this (2026-09-24), each first mistaken for a
  problem in the code:
  - Floci's CloudFront ignores tags passed at creation, so the first re-apply "changes" the distribution. Proved with
    the AWS CLI, not assumed. CI applies once more before its no-changes check, with a comment saying why.
  - Floci 2.1.0 only routes a CloudFront request by the distribution's generated domain. With the default suffix
    (`cloudfront.net`) a browser cannot reach it; setting `FLOCI_SERVICES_CLOUDFRONT_DOMAIN_SUFFIX=cloudfront.localhost`
    makes the domain `<id>.cloudfront.localhost`, which browsers send to this machine. An existing distribution keeps
    its old domain until it is replaced.
- **Read the docs for your version.** Floci's docs on `main` describe features newer than the pinned release. Check
  the docs at the release tag (`?ref=2.1.0` on GitHub).
- **A 200 is not proof.** Floci answers HTTP 200 on port 4566 for almost anything (an S3 "list buckets" reply), so a
  health check must look at the content. `dev-up` checks the portal's page title.
- **The provider must know every endpoint.** Each service OpenTofu calls is listed in the provider's `endpoints`
  block. A missing one would send that call to real AWS (where the dummy keys fail), which is also why the dummy keys
  are there: this code cannot reach real AWS by accident.
- **Resetting the wrong way.** Docker Desktop's "Purge data" deletes Floci's data but leaves the bootstrap state, so
  the next run believes the bucket exists. Use `dev-down.ps1 -Reset`.
- **The dashboard holds the Docker socket.** That is what makes its EC2 terminal work, and it means floci-dash can
  control Docker on your machine. Keep it on loopback, read its changelog before bumping the pinned digest, and close
  its tab when you are not using it (its terminal WebSocket does not check which site is asking). On real AWS, the
  equivalent of that terminal is Session Manager, which needs no open port and no SSH key.
- **Hand-made resources are not in state.** A bucket made in floci-dash survives until a reset and is invisible to
  OpenTofu. Fine for experiments; anything that should last goes in code.

## Check yourself

<details><summary>Why does the bootstrap root keep its state in a local file?</summary>

Its job is to create the bucket the other roots store state in. Before it runs, there is no bucket to store its own
state in. Teams usually create the state bucket once, by a small bootstrap stack or by hand, and protect it.

</details>

<details><summary>What stops two people running `tofu apply` on the same state at once?</summary>

The S3 backend's lock. OpenTofu writes a `.tflock` object with a conditional write that fails if the object already
exists, so the second run gets "Error acquiring the state lock" instead of corrupting the state. Here that was tested
by planting a lock object and watching `plan` refuse.

</details>

<details><summary>Why put CloudFront in front of a private bucket instead of making the bucket public?</summary>

A public bucket exposes every object and gives no caching, TLS on your own domain, or edge protection. With origin
access control the bucket stays private, only one distribution can read it, and CloudFront adds caching, HTTPS and a
place for a web application firewall.

</details>
