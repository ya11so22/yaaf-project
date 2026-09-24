# Research: the SA job market, and whether this project is on the right track

**Date:** 2026-09-24. **Status:** research and a proposal. Nothing here is decided yet; the decisions it asks
for become ADR-0018 onward once the owner answers them.
**Evidence labels used below:** *primary* (AWS pages or the posting itself), *secondary* (blogs, aggregators;
treat their numbers as rough), *inference* (my reasoning from the above).

## 1. Questions

1. What does the Solutions Architect (SA) market look like now, and where is it going?
2. What do SAs and DevOps engineers really do in production?
3. What do employers ask for at 1 to 3 years of experience?
4. Is this project on the right track, and should anything change at the root?
5. Can real AWS replace or add to Floci without real cost?

## 2. Findings: the market

### 2.1 A sample of real postings (Indeed, pulled 2026-09-24)

A small, hand-picked sample, not a market tally. The "tally real US SA postings" milestone stays open, but it
now has a start.

| Posting | Years asked | Signals in the text |
|---|---|---|
| Easy Dynamics, Cloud Engineer (remote, $70–155k) | **1+** | Docker/K8s, Terraform, CI/CD, scripting, FinOps, "document ... architecture decisions", SA cert preferred |
| AWS, Solutions Architect (LATAM CSC) | **2+** in a domain | Cloud design, migration strategy, presenting to executives, coding, cert preferred |
| Sporttrade, SRE ($150–170k) | 5+ | EKS+GKE, Terraform, on-call, postmortems, SLOs, "proving that backups actually restore", Postgres, Kafka |
| Robots & Pencils, Sr SA (AWS AI) | 7–10+ | Bedrock, RAG, **ADRs**, Well-Architected, multi-account/Control Tower, SOC2/HIPAA, IaC, observability |
| Moog, Solutions Architect ($150–180k) | 8+ | **ADRs**, Terraform, CI/CD in regulated settings, NIST/CMMC, hybrid cloud, event-driven integration, TCO |
| Kong, Forward Deployed Engineer | 8+ | K8s, Terraform/Helm/GitOps, migration tooling, reference architectures |
| acuCyber, AWS DevOps Engineer | 10–14+ | Terraform, Transit Gateway/VPN hybrid networking, CloudWatch/Config, EKS, NIST 800-53, SA cert |
| Cognizant, AWS WorkSpaces Migration Architect | 14+ | Terraform, GitOps, GitHub Actions, migration waves, cutover and rollback, HA/DR, SA cert preferred |

Counts across the 8 (inference from the table): IaC 7/8; CI/CD 7/8; written decisions, ADRs or reference
architectures 6/8; regulated or compliance work 5/8; the AWS SA certification named 5/8; migration 4/8;
Kubernetes 4/8; observability or SLOs 4/8; cost/TCO/FinOps 3/8; DR proven, not just designed 2/8;
generative AI 1 to 2 of 8.

### 2.2 What this says (inference, with the sources that support it)

- **"Solutions Architect" at 1 to 2 years is mostly not an entry title.** Six of the eight postings ask for 5 to
  14+ years. AWS's early-career "Solutions Architect - 2026 (US)" needs a graduation date from Aug 2024 to Aug
  2026 (*primary*, amazon.jobs 10430661), so it probably excludes the owner. The best-fitting door found is
  AWS's own regular SA role, which asks for **2+ years in a technology domain** (*primary*, amazon.jobs
  10520843; a LATAM posting, as the US one returned 404). Partner consultancies ask for more: Mission Cloud
  asks 5+ years consulting and 3+ on AWS (*secondary*).
- **The realistic path is Cloud/DevOps/Platform Engineer now, SA next**, preferably at an AWS partner
  (Caylent, Mission, Rackspace, 2nd Watch) or at a cloud-heavy product company, where the move to SA is
  common. The project should serve both at once: engineering proof for the first role, design proof for the
  second.
- **The DevOps title is changing into "Platform Engineer"** (*secondary*, one salary blog claims DevOps
  postings are down 54% since 2023 and platform roles up 312%; treat the numbers as rough, the direction is
  consistent across sources).
- **Growth is in AI infrastructure and inference serving** (*secondary*). For an SA, the AI part looks like
  the Robots & Pencils posting: Bedrock, RAG, guardrails and cost trade-offs, not training models.
- **The AWS SA Associate certification is the cheapest checkbox.** Five of eight postings name it. It is not a
  project item, but it is what screeners filter on.
- **Hiring managers want proof of work that runs** (*secondary*, freeCodeCamp, April 2026): deployed with a real
  URL, CI/CD, IaC, monitoring and alerting, a README that explains decisions, and real commit history. Red
  flags: tutorial clones, half-finished projects, not being able to explain decisions.

## 3. Findings: real AWS versus Floci

- **The owner is not eligible for the new $100–200 Free Tier credits.** They go to accounts created after
  2025-07-15, one per person. The terms say: "You are not eligible to receive Free Tier Credits for more than
  one account", and creating extra accounts to get offers removes eligibility (*primary*, aws.amazon.com/free/terms).
  **Do not open a second account for credits.** The owner's older account is on the legacy tier, whose 12 months
  have ended, so it bills normally.
- **The small-budget route (inference, prices to be checked with the AWS Pricing Calculator):** a time-boxed EKS
  proof run costs roughly the EKS control plane ($0.10/h) plus two small nodes, a NAT gateway ($0.045/h,
  *secondary*) and an ALB: about $0.35 to $0.50 per hour. A 3-hour run is under $2, and **ten proof runs cost
  under about $20**. The risks are resources left running and silent costs (NAT, public IPv4 at $0.005/h,
  CloudWatch Logs without retention), not the runs themselves.
- **Budget alarms are not a brake.** Billing data lags by hours. The real protection is automated teardown: every
  run gets a TTL and a scheduled `destroy`, plus a "nothing left running" check. Budget alerts are the second net.
- **Credits without a new account:** AWS Community Builders gives $500 of credits a year plus an exam voucher
  (*secondary*); the 2026 intake closed on 2026-01-21, so the next one is about January 2027 and depends on
  publishing AWS content. This project's write-ups are that content.
- **Floci is the right tool for the inner loop, not for proof.** It is free, with no account (LocalStack now needs
  an account and token and is free only for non-commercial use, *secondary*). But it does not enforce IAM trust
  conditions, gives one node, health checks are cosmetic, and the restart problems in ADR-0014 cost real time.
  Industry uses emulators the same way: fast local tests, with real cloud for the claims that matter.

## 4. Is the project on the right track?

**Mostly yes. Do not scrap it.** The rare part is already here: 17 ADRs, a postmortem from a deliberate
failure, honest evidence labels and a working GitOps loop. Six of the eight postings ask for exactly that kind of
written decision record. The bank background also matters, since five of eight postings mention regulated
work.

**Three root-level problems:**

1. **The main claims are unproven where it matters.** Everything is "verified on Floci". The things an SA
   interviewer probes (IAM trust, multi-AZ, TLS, load balancer health, DR restores, real cost) are exactly what
   Floci cannot show. Much of the recent effort went into making the emulator stay up (smee, k3s repair,
   restart handling). That gives good stories, but it is not AWS skill.
2. **The workload has no real state.** Online Boutique keeps only a Redis cart. RPO, point-in-time restore,
   migration of data and DR tiers have nothing to act on, and those are core SA topics. Online Boutique is also
   a very common portfolio demo.
3. **The scope is too wide to finish.** Four phases plus 13 architecture milestones. An unfinished project is a
   named red flag; a finished, smaller one is not.

## 5. Proposal: keep the repo, move its centre

### 5.1 Reframe it as one customer engagement

A fictional customer: **a mid-size retailer that takes card payments (PCI DSS in scope)**, moving its storefront to
AWS. This keeps Online Boutique, uses the owner's regulated-industry background, and gives every artefact one
story: discovery, requirements, design, Well-Architected review, build, operate, break, review again.

### 5.2 Give the workload state, through a real migration

Online Boutique already contains `shoppingassistantservice`, which is tied to Google Cloud (Gemini and AlloyDB).
**Replatforming it to AWS** (Bedrock for the model, RDS or Aurora PostgreSQL with pgvector for retrieval) is at once:

- a real cross-cloud migration, which the 7 Rs work can use as a worked example ("replatform");
- the generative AI / RAG design that SA roles ask for, replacing the self-hosted CPU LLM plan (Phase 3) as the
  main AI story. Self-hosted serving stays as the alternative weighed in the ADR;
- a stateful service, so RPO, point-in-time restore and DR tiers can be measured, not only described.

Locally: Postgres with pgvector (Floci's RDS runs real containers) and a small local model or stub behind the
same interface. On AWS: Bedrock, with a few cents of calls.

### 5.3 Two environments, each with a clear job

| | Floci (local, free) | Real AWS (existing account, capped) |
|---|---|---|
| Job | Inner loop, CI smoke tests, GitOps, failure drills | Proof runs only, time-boxed, destroyed afterwards |
| Proves | The pipeline and manifests work; the process | OIDC negative trust test, IRSA/Pod Identity, ALB+ACM TLS and health, multi-AZ failover, RDS PITR against the RPO, real cost from Cost Explorer |
| Evidence | "verified on Floci" | "verified on real AWS", with logs, screenshots, the bill |

Keep Floci working, but stop investing in emulator plumbing beyond that. Turn the restart findings into the
upstream contribution (the "external validation" goal).

### 5.4 Cut scope to a finishable shape

1. **Close Phase 1** as it is: threat model, pre-merge deploy check, README demo.
2. **Architecture track, first half:** requirements, views, Well-Architected review v1 with a findings register.
3. **Build the findings into fixes:** the stateful assistant service, observability with SLOs and alerts, policy as code.
4. **Proof runs on real AWS**, about $20 total, each tied to one finding.
5. **DR drill and cost model from real numbers**, then Well-Architected review v2 and the interview kit.

Dropped or deferred: Phase 4 MLOps (dropped), per-PR environments and DORA metrics (deferred, optional),
the self-hosted LLM (an alternative in an ADR, not a phase), multi-account governance (designed on paper, as a
single account cannot show it).

## 6. Decisions for the owner

1. Real AWS: approve a capped budget (proposed: $25 total, with automated teardown) on the existing account,
   or stay fully local and wait for credits?
2. The customer scenario: payments retailer (proposed) or a regulated bank's storefront?
3. The scope cut in 5.4, including dropping Phase 4 and replacing the Phase 3 self-hosted LLM with the
   Bedrock/pgvector replatform?
4. The AWS SA Associate exam in parallel (about $150), outside the project?

### Answers (2026-09-24)

1. No planned spend and no risk of accidental spend. The capped-budget idea in section 3 is withdrawn; see the
   zero-spend lane in [ADR-0020](../../adr/0020-zero-spend-real-aws-lane.md) (proposed).
2. Payments retailer: [ADR-0018](../../adr/archive/0018-scenario-card-payments-retailer.md).
3. Scope cut and replatform accepted: [ADR-0019](../../adr/archive/0019-scope-cut-and-assistant-replatform.md).
4. The certification is later and out of scope. The project also becomes a learning course, with guides in
   [`docs/guides/`](../guides/README.md).

## Sources

- AWS Free Tier terms: https://aws.amazon.com/free/terms/ ; FAQ: https://aws.amazon.com/free/free-tier-faqs/
- Free Tier before 2025-07-15: https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/billing-free-tier.html
- Free plan instance limits for EKS: https://github.com/aws-samples/eks-workshop-v2/issues/1644
- Free Tier costs that surprise: https://infratally.com/articles/aws-free-tier-2026/
- AWS early-career SA: https://www.amazon.jobs/en/jobs/10430661/solutions-architect-2026-us
- AWS SA (2+ years): https://www.amazon.jobs/en/jobs/10520843/solutions-architect-latam-csc-sa
- Hiring managers: https://www.freecodecamp.org/news/how-to-land-your-first-cloud-or-devops-role-what-hiring-managers-actually-look-for/
- DevOps/platform trend: https://www.recruitingfromscratch.com/blog/devops-platform-engineer-salary-in-2026-real-data-from-1-9-million-job-postings-18d84
- LocalStack account requirement: https://blog.localstack.cloud/the-road-ahead-for-localstack/
- AWS Community Builders: https://builder.aws.com/content/32g2lQ7kc3Py8kKIYGS15Pe8VSS/aws-community-builders-program
- AWS partners: https://www.raftlabs.com/blog/top-aws-consulting-companies
- Postings: Indeed via the job-search connector, 2026-09-24 (Easy Dynamics, Sporttrade, Robots & Pencils, Moog,
  Kong, acuCyber, Cognizant).
