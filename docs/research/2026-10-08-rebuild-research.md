# Research: rebuilding the project on real cloud, cheaply and safely

**Date:** 2026-10-08. **Asked by:** the owner, after Floci work kept costing more than it taught. **Method:** a
deep-research run (5 search angles, 19 sources fetched, 25 claims put to a 3-vote adversarial check, 24 confirmed, 1
refuted), then four focused follow-ups restricted to primary sources (AWS Price List files, vendor docs, project repos).
A record: it is not rewritten later; the plan that came from it is [`PLAN.md`](../../PLAN.md).

Confidence: **high** = a primary source read this day; **medium** = a primary source plus inference, or a reliable
secondary source; **low** = search snippets or opinion. Prices are us-east-1, USD, fetched 2026-10-08.

## 1. What real AWS costs for this workload

| Item | Price | Confidence | Source |
|---|---|---|---|
| EKS control plane | $0.10 per cluster-hour ($0.60 on extended support) | high | AWS Price List `AmazonEKS` (2026-09-28); [EKS pricing](https://aws.amazon.com/eks/pricing/) |
| EKS Auto Mode fee | per instance-hour, on top of EC2: t4g.medium $0.00403, t4g.large $0.00806, m7g.large $0.00979; same for Spot | high | same |
| EC2 Graviton, on-demand / Spot | t4g.medium $0.0336 / $0.0144; t4g.large $0.0672 / $0.0301; m7g.large $0.0816 / $0.0367 | high (Spot prices move hourly) | EC2 price map, `spot.js` |
| Spot interruption, us-east-1 | t4g.medium and t4g.large 15–20 %, c7g.large 5–10 %, m7g.large over 20 % | medium (advisor file dated 2026-03-20) | Spot advisor data |
| ALB | $0.0225 per hour + $0.008 per LCU-hour | high | Price List `AWSELB` |
| Managed NAT gateway | $0.045 per hour + $0.045 per GB | high | EC2 price list |
| fck-nat (NAT instance on t4g.nano) | about $0.0042 per hour, no per-GB fee; one instance per AZ, so dev and demo only | high (maintainer's figures, checkable) | [fck-nat](https://github.com/AndrewGuenther/fck-nat) |
| Public IPv4 | $0.005 per address-hour, in use or not | high | [VPC pricing](https://aws.amazon.com/vpc/pricing/) |
| RDS PostgreSQL db.t4g.micro | $0.016 per hour; gp3 $0.115 per GB-month | high | Price List `AmazonRDS` (2026-10-06) |
| Aurora Serverless v2 | $0.12 per ACU-hour; can pause at 0 ACU (resume about 15 s), storage still billed | high | [auto-pause docs](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2-auto-pause.html) |
| ElastiCache | cache.t4g.micro Valkey $0.0128 per hour; Serverless Valkey floor about $0.0084 per hour (100 MB minimum) | high | Price List `AmazonElastiCache` |
| ECS orchestration | no charge; Fargate ARM $0.0324 per vCPU-hour, $0.0036 per GB-hour, per second, 1-minute minimum | high | [ECS pricing](https://aws.amazon.com/ecs/pricing/), [Fargate pricing](https://aws.amazon.com/fargate/pricing/) |
| Small always-on items | Route 53 zone $0.50/month; ECR $0.10/GB-month; S3 $0.023/GB-month; KMS key $1/month; Secrets Manager $0.40/secret-month; CloudWatch Logs $0.50/GB ingested | high | Price List files |
| Managed Argo CD (EKS capability) | $0.03 per capability-hour + $0.0015 per Application-hour | high | [EKS pricing](https://aws.amazon.com/eks/pricing/) |
| AWS FIS | $0.10 per action-minute | high | [FIS pricing](https://aws.amazon.com/fis/pricing) |

**Worked cost of one 3-hour session** (the arithmetic is in the follow-up report; 20–30 minutes of create and destroy come
on top of each session):

| Design | Per session | 8 sessions a month, plus always-on items |
|---|---|---|
| EKS, 2 × t4g.medium Spot, 1 ALB, RDS micro, cache micro | about $0.65 | about $5.90 |
| The same on EKS Auto Mode | about $0.67 | about $6.10 |
| k3s on one t4g.large/xlarge Spot instance, no ALB | $0.12–0.21 | $1.65–2.35 |
| ECS on Fargate ARM, 12 tasks, ALB, RDS, cache | about $0.75 | about $6.75 |

**The real risk is forgetting to tear down:** the EKS design left running costs about **$5.20 a day**, so a $20 ceiling
lasts about 4 days. Creating an EKS cluster with Terraform takes 20–25 minutes ([EKS
Workshop](https://eksworkshop.com/docs/introduction/setup/your-account/using-terraform)); destroy fails when controllers
leave load balancers, ENIs or security groups behind, so add-ons go first (the [EKS Blueprints teardown
order](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/)).

## 2. Hard cost guardrails

- **AWS Budgets actions only deny or stop** (apply an IAM policy or an SCP, or stop named EC2/RDS instances). They cannot
  delete an EKS cluster, a load balancer or a NAT gateway, and billing data lags by hours. The first two budgets with
  actions are free. *High* ([Budgets controls](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-controls.html),
  [pricing](https://aws.amazon.com/aws-cost-management/aws-budgets/pricing/)).
- **AWS spend limit (announced 2026-09-16)** is a real hard stop (it pauses everything at the limit) but needs the Paid
  Plan, has a $20 minimum, is in limited release, and is probably not offered on older accounts. *High* for the
  mechanism, *medium* for availability ([announcement](https://aws.amazon.com/about-aws/whats-new/2026/09/New-AWS-Builder-Experience),
  [docs](https://docs.aws.amazon.com/accounts/latest/reference/create-spend-limit.html)).
- **Free Tier credits are for new customers only**; an existing account keeps only the always-free offers. *High*
  ([FAQ](https://aws.amazon.com/free/free-tier-faqs/)).
- **SCPs** can allow one Region and an instance-type list, and deny whole services. They apply to member accounts of an
  AWS Organization, not to the management account. *Medium* (examples read from search summaries).
- **Teardown tools:** `ekristen/aws-nuke` is maintained (v3.68.3, 2026-10-02). A TTL tag plus a scheduled `tofu destroy`
  in GitHub Actions is a documented OpenTofu pattern. *High* / *medium*.
- **Infracost** CI plan is free for 1,000 runs a month; OpenTofu support is shown by third parties, not by Infracost's
  own docs. *Medium*. **Cost Anomaly Detection** is free but needs up to 24 hours, too slow for one session. *High*.
- **GitHub OIDC to AWS:** a role trusted on `token.actions.githubusercontent.com:aud = sts.amazonaws.com` and an exact
  `:sub`; IAM rejects a missing or wildcard-only `sub`. *High*
  ([IAM docs](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html#idp_oidc_Create_GitHub)).

**Conclusion:** no single AWS feature caps spend at a few dollars. Safety comes from layers: an account that holds
nothing else, SCPs that make the expensive things impossible, sessions that destroy themselves, a scheduled reaper
for what a failed pipeline leaves, and a Budgets action as the last line.

## 3. Where else the cluster could live

| Option | Idle | Per session | AWS fidelity | Notes (confidence) |
|---|---|---|---|---|
| kind or k3s on a GitHub-hosted runner | $0 | $0 | Kubernetes only | Standard runners are free and unlimited for public repos; `ubuntu-24.04-arm` is 4 vCPU / 16 GB / 14 GB disk; 6-hour job limit (high, [runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [limits](https://docs.github.com/en/actions/reference/limits)). Argo CD's own e2e tests install k3s on runners (high) |
| Floci | $0 | $0 | API shape only | IAM enforcement is opt-in and partial (high, [Floci IAM](https://floci.io/floci/services/iam/)); measured 2026-10-08: conditions and resource-scoped denies ignored |
| LocalStack | $0 Hobby (non-commercial, auth token) | — | EKS only on paid tiers (about $89/month) | Community edition ended 2026-03-23 (high, [LocalStack](https://blog.localstack.cloud/2026-upcoming-pricing-changes/)) |
| Vendor sandboxes | $0 | $0 | Real, but crippled | KodeKloud caps an EKS cluster at 2 vCPU / 4 GiB and appears to deny OIDC providers; Builder Center sandboxes are tied to workshops, none for EKS at launch (medium) |
| GKE / AKS / DOKS / Civo | $0 control plane (GKE via a monthly credit) | cents per hour | none | Billed per second or hour, card on file; tells a different cloud's story (medium) |

## 4. Proven practice for the platform

- **GitOps:** a config repository separate from app repositories; environments as directories, not branches; promotion
  by pull request (Argo CD's [best practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)).
  [gitops-bridge](https://github.com/gitops-bridge-dev/gitops-bridge) is the reference split: IaC creates the cluster and
  hands metadata to Argo CD, which installs every add-on; no Helm from Terraform. *High*.
- **EKS for small teams:** the [EKS Best Practices Guide](https://docs.aws.amazon.com/eks/latest/best-practices/introduction.html)
  as the checklist (`hardeneks` checks against it). [Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
  runs Karpenter, load balancing, EBS CSI and the Pod Identity agent for you. EKS Blueprints are patterns to copy, not a
  module to depend on. *High*.
- **Workload identity:** EKS Pod Identity is AWS's recommended way (no OIDC provider per cluster); secrets through
  External Secrets Operator ([Argo CD recommends](https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/)
  syncing secrets in the destination cluster). *High*.
- **IaC quality:** `tofu test` with `command = plan` and `mock_provider` runs offline; Trivy has absorbed tfsec;
  Checkov or conftest for house rules. *High*.
- **SLOs:** kube-prometheus-stack in the cluster; Sloth generates the SRE Workbook's multiwindow, multi-burn-rate alerts
  ([workbook](https://sre.google/workbook/alerting-on-slos/)). Managed Prometheus/Grafana stays a costed design. *High*.
- **Backup and DR:** RDS automated backups and snapshots; [AWS Backup supports EKS](https://aws.amazon.com/about-aws/whats-new/2025/11/aws-backup-supports-amazon-eks)
  since November 2025; Velero as the portable option. In GitOps the cluster rebuilds from git; the real test is the data. *High*.
- **Supply chain:** GitHub artifact attestations (SLSA Build L2, L3 from a reusable workflow), verified at admission by
  Kyverno `verifyImages`; OpenSSF Scorecard. *High*.
- **The app:** Online Boutique (11 polyglot gRPC services, Locust load generator; its managed-datastore options are
  GCP-only) versus AWS's [retail-store-sample-app](https://github.com/aws-containers/retail-store-sample-app) (5
  services: UI, catalog, cart, orders, checkout; a "default" variant on RDS, DynamoDB and ElastiCache, a "minimal" one
  in-cluster; Helm charts, OpenTelemetry, a load generator; the app the EKS Workshop uses). Both are labelled
  educational. *High*.
- **What reviewers look at:** no survey shows that "ran on real AWS" beats local Kubernetes. Reviewers spend minutes, do
  not run the code, and judge the README, the decisions and their reasons, a diagram, cost awareness and CI. *Low*
  (career guides, opinion).

## 5. AI agents on the platform

- **The identity trap:** Claude Routines and cloud sessions push as the owner's GitHub identity, and an identity a rule
  lets bypass is not blocked ([Routines](https://code.claude.com/docs/en/routines)). So the ruleset on `main` has no
  bypass for admins, and team agents run as their own GitHub Apps (`claude-code-action` with
  `actions/create-github-app-token`; installation tokens last an hour and can be narrowed per repository). *High*.
- **Gates:** rulesets with required checks; "require code scanning results" blocks only alerts a PR introduces (a
  ratchet); `dependency-review-action` and OSV-Scanner for vulnerable and known-malicious packages; a check that fails on
  any new dependency covers invented package names. Copilot's coding agent is the reference pattern: its own branch, no
  workflow runs without approval, a firewall allowlist. *High*.
- **Running agents safely:** Simon Willison's [lethal trifecta](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/)
  (private data, untrusted content, a way out: cut one); Anthropic's sandboxing write-up. *High*.
- **Simulated customers:** Locust or k6 make the volume; LLM agents should write and vary the journeys and run a few
  exploratory sessions (Playwright MCP), not drive every virtual user. No credible source shows LLM-per-user load. *Medium*.
- **Chaos:** Chaos Mesh and LitmusChaos are free on any cluster; AWS FIS costs $0.10 per action-minute and its EKS pod
  actions need EKS 1.30+. *High*.

## 6. AWS knowledge tooling

- **AWS Knowledge MCP** (`https://knowledge-mcp.global.api.aws`): remote, free, no credentials; the safe default for
  agents. **AWS MCP Server** (GA 2026-05-06, no charge): docs and skills without credentials, API calls with IAM; it
  replaces the API and Knowledge servers when adopted. awslabs/mcp still ships Documentation, IaC, EKS, Pricing, Billing
  and Cost Management, and a Well-Architected security server (stdio via `uvx`); its Terraform, Cost Explorer, diagram
  and CloudFormation servers are gone from `main`. *High*.
- Claude Code reads a committed `.mcp.json` in cloud sessions; the default trusted network allowlist covers `*.api.aws`
  and `pypi.org`. *High* ([MCP](https://code.claude.com/docs/en/mcp), [cloud environments](https://code.claude.com/docs/en/cloud-environments)).
- The Well-Architected Tool and the Pricing Calculator are free. The EKS Workshop, Skill Builder and the SAA/SAP exam
  guides are the learning path (SAP-C02 is reportedly replaced on 2026-11-17: *low*, check before booking).

## Open and unconfirmed

Pod Identity pricing (believed free); RDS and ElastiCache billing minimums; SCP example pages (read from summaries);
whether the spend limit is offered on old accounts; the exact retail-store-sample-app datastores per service (to read
when vendoring); Infracost's own OpenTofu statement; the cgroup version of GitHub's runners (v2 was measured on
`ubuntu-24.04-arm` on 2026-10-08 by this project's `environment` workflow).
