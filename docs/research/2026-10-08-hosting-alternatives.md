# Keep Floci, add borrowed real AWS

Floci is still the right foundation for yaaf-project in October 2026. No other option gives AWS-shaped APIs, a real Kubernetes cluster, real PostgreSQL and a real Redis-compatible cache for free, without limit, inside CI, with no way to bill the owner. The free LocalStack plan excludes EKS, RDS, ElastiCache, ALB, ECR and IAM enforcement, and Moto has no cluster behind its EKS API. The best overall architecture is a **hybrid**. Floci and the three OpenTofu roots run on GitHub's free arm64 runners on every PR, after every merge, and for the on-demand demo. Separately, **time-boxed real-AWS evidence runs** happen in vendor-owned sandbox accounts that can never bill the owner's account; the free AWS Builder Center sandbox is the first candidate. Those runs are recorded as "verified on real AWS (sandbox, date)". The owner's old account has **no hard spending cap**. AWS's new spend limits (September 2026) are only for customers who sign up through the new flow, and that would mean a second account, so the owner's account stays off-limits except for the IAM-only lane already rejected in D20. **No free host keeps the arm64 shop running all the time** without a billable account. Oracle halved its Always Free Ampere allowance to 2 OCPU / 12 GB on 2026-06-15. So "always on" belongs to the static Vercel showcase and a recorded demo, not to a cluster. Backups should go **encrypted to GitHub** (Actions artifacts or GHCR OCI artifacts), which cannot bill an account with no payment method, rather than to Cloudflare R2, which needs a checkout, can bill and has no cap. The cloud session should stay on the AWS API layer and static manifest checks. A k3s cluster can be forced to start there, but it relies on a deprecated cgroup v1 fallback that is due to be removed.

*Evidence labels used throughout:* **[Doc]** primary vendor documentation; **[Secondary]** press or community write-up; **[Anecdotal]** forum or user report; **[Observed]** read from this repository or this session's VM; **[Inference]** reasoning not yet tested. The project's own labels (*designed*, *verified on Floci*, *verified on real AWS*) apply to the project's claims, not to this report.

## Floci is still the only emulator that runs the whole stack for free

The emulator market changed in March 2026, and that change explains Floci's rise. Since 2026-03-23 LocalStack ships a single image that needs an auth token **[Doc]** ([LocalStack blog](https://blog.localstack.cloud/localstack-single-image-next-steps/)). Its free **Hobby** plan is non-commercial. Its licensing table puts ECR, RDS, ElastiCache and ELBv2 on Base and above, EKS on Ultimate only, and IAM policy enforcement off Hobby **[Doc]** ([LocalStack licensing](https://docs.localstack.cloud/aws/licensing/)). Base costs **$39 per licence per month** and Ultimate **$89**, billed annually **[Doc]** ([LocalStack pricing](https://www.localstack.cloud/pricing)). For this project's service list, LocalStack therefore costs about $1,068 a year, and it would need a card. Pinning a frozen pre-March community tag gains nothing, because these services were already Pro-only before the change **[Inference]**. Even paid LocalStack EKS is k3d/k3s with Traefik, and 40 of 70 EKS operations are implemented **[Doc]** ([LocalStack EKS](https://docs.localstack.cloud/aws/services/eks/)), so it is no closer to managed EKS than Floci is. Moto is ruled out for a different reason. Its EKS support is 17 control-plane operations and nothing serves the Kubernetes API **[Doc]** ([Moto EKS](https://docs.getmoto.org/en/latest/docs/services/eks.html)), so kubectl and Argo CD have nothing to talk to. It stays useful only for unit-testing scripts that call AWS. MiniStack, the other free post-March alternative, has no primary-source evidence of real EKS **[Secondary]** ([earezki.com](https://earezki.com/ai-news/2026-03-30-ministack-the-best-alternative-to-localstack/)).

Floci itself is MIT-licensed, has about **26.6k stars**, and ships stable releases on the 1st and 3rd Tuesday of each month (2.2.0 on 2026-10-06) **[Doc]** ([floci-io/floci](https://github.com/floci-io/floci); [releases](https://github.com/floci-io/floci/releases)). It runs EKS as a real k3s container per cluster, RDS as a real PostgreSQL container and ElastiCache as a real **Valkey** container, all through the Docker socket **[Doc]** ([Floci EKS docs](https://raw.githubusercontent.com/floci-io/floci/main/docs/services/eks.md)). That is why it fits D22.

The fidelity gaps are specific and a reviewer could over-read them. **All node groups share one k3s node**, and add-ons are metadata only. Default routes, internet gateways, NAT and peering are not programmed, so "private subnets" give no real isolation **[Doc]** ([Floci EKS docs](https://raw.githubusercontent.com/floci-io/floci/main/docs/services/eks.md)). **IAM enforcement is off by default.** The `test` access key always bypasses it, MFA condition keys are never populated, and most IAM management actions are evaluated against `*` (issue #4979) **[Doc]** ([Floci IAM docs](https://floci.io/floci/services/iam/)). Until 2.1.0, every AWS managed policy returned `Allow *` **[Secondary]** ([Classmethod, 2026-09-30](https://dev.classmethod.jp/articles/floci-2026-09-local-ca-iam-policy-update/)). AWS Backup jobs are simulated, FIS injects no faults and Auto Scaling policies are inert **[Doc]** ([Floci README](https://github.com/floci-io/floci)). This project's own findings add that security-group source CIDRs and IMDSv2 `HttpTokens=required` are not enforced, and that after an abrupt stop k3s can come back on a stale IP while Floci still reports the cluster ACTIVE **[Observed]** (`docs/research/2026-09-24-floci-upstream-findings.md`, `infra/README.md`). Two claims remain unproven:

- No fetched source shows an ALB on Floci forwarding real HTTP traffic. Until the project proves it, treat ALB as API-level only **[Inference]**.
- No source shows Floci S3 rejecting a second `PutObject` with `If-None-Match: *`, which is what makes OpenTofu's `use_lockfile` actually lock **[Inference]**. D22's "native locking" is therefore a claim that needs a planted-fault test.

The project risk is Floci's youth. Visible releases begin mid-2026, 2.0.0 broke compatibility, and no governance or backer was found. The MIT licence and image pinning by digest are the mitigation **[Inference]**.

| Emulator | EKS | RDS PostgreSQL | ElastiCache | ALB / ECR | IAM enforcement | Cost / card | Verdict |
|---|---|---|---|---|---|---|---|
| **Floci 2.2** | Real k3s, single shared node | Real PostgreSQL | Real Valkey | In-process ALB (data plane unproven); ECR mirrored into k3s | Real but opt-in; `test` key bypasses | Free, MIT, no account | **Keep as foundation** [Doc] |
| LocalStack Hobby | No | No | No | No | No | Free, token, non-commercial | Unfit [Doc] |
| LocalStack Ultimate | k3d/k3s + Traefik, 40/70 ops | Yes | Yes | Yes | Yes | ~$89/month annual, card | Paid, no fidelity gain over Floci on EKS [Doc] |
| Moto server | 17 metadata ops, no cluster | Metadata (inferred) | Metadata (inferred) | Metadata | Partial | Free | Unit tests only [Doc]/[Inference] |
| MiniStack | No evidence | Real container (claimed) | Real Redis (claimed) | Unverified | Unverified | Free, MIT | Unverified [Secondary] |

## Real AWS can be borrowed, but not safely run on the owner's account

On the owner's account the rules do not move. Accounts created before 15 July 2025 stay on the legacy Free Tier. For an account older than 12 months, that leaves only the Always Free offers; credits and the Free plan are for new customers only **[Doc]** ([AWS News Blog, 2025-07-15](https://aws.amazon.com/blogs/aws/aws-free-tier-update-new-customers-can-get-started-and-explore-aws-with-up-to-200-in-credits/); [Free Tier FAQ](https://aws.amazon.com/free/free-tier-faqs/)).

**No hard cap exists for this account.** AWS Budgets runs on billing data that is updated "at least once per day", so its actions only limit how long a charge runs **[Doc]** ([Budgets best practices](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-best-practices.html)). SCP-based actions do not help either, because "SCPs don't affect users or roles in the management account" **[Doc]** ([AWS Organizations SCPs](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)).

AWS did ship a real cap on 2026-09-16. Per-project **spend limits** from $20 pause the project instead of accruing charges **[Doc]** ([AWS News Blog, 2026-09-16](https://aws.amazon.com/blogs/aws/aws-reimagines-the-getting-started-experience/)). The feature only exists in AWS Settings, which is "available when you sign up using Sign up for AWS (new)". It is "releasing to a limited number of customers" and requires a Paid Plan **[Doc]** ([AWS Settings](https://docs.aws.amazon.com/accounts/latest/reference/use-aws-settings.html); [spend limits](https://docs.aws.amazon.com/accounts/latest/reference/create-spend-limit.html)). No source describes a path for existing accounts **[Secondary]** ([Help Net Security](https://www.helpnetsecurity.com/2026/09/17/aws-spend-limit-agent-set-permissions/)). Getting it would require a new sign-up, which is the second account the owner has ruled out. It is context, not an option.

A strictly capped lane on the owner's account could still prove something real at about $0: identity work only. The pieces are:

- GitHub Actions OIDC into a role whose trust policy pins `sub` to the repo and branch **[Doc]** ([GitHub OIDC in AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)).
- A negative test showing that a fork or another branch is refused.
- Free Access Analyzer policy validation **[Doc]** ([Access Analyzer pricing](https://aws.amazon.com/iam/access-analyzer/pricing/)).
- The 90-day CloudTrail event history, which is free **[Doc]** ([CloudTrail pricing](https://aws.amazon.com/cloudtrail/pricing/)).

**Watch out:** repositories created after 15 July 2026 use immutable subject claims that include owner and repository IDs **[Doc]** (same GitHub page).

The traps sit next to the free items. Custom policy checks cost $0.002 per call, an unused-access analyzer costs $0.20 per role per month, and a KMS customer managed key costs $1 per month **[Doc]** ([Access Analyzer pricing](https://aws.amazon.com/iam/access-analyzer/pricing/); [KMS pricing](https://aws.amazon.com/kms/pricing/)). The dominant risk is a leaked credential. AWS's own November 2025 incident report describes miners deployed "within 10 minutes" of access with stolen IAM credentials **[Secondary]** ([AWS Security Blog](https://aws.amazon.com/blogs/security/cryptomining-campaign-targeting-amazon-ec2-and-amazon-ecs), via excerpts). EKS, NAT, RDS, the ALB and public IPv4 can never be proven at $0 on this account.

D20 already rejected this lane on 2026-10-03. Nothing found here contradicts that decision. The lane proves a narrow slice, and its residual risk (root compromise, a human error in the allow-list, a day of Budgets lag) is small but not zero **[Inference]**.

The real-AWS evidence therefore has to come from accounts the owner does not own, and these exist:

- **AWS Builder Center sandbox** (launched 2026-07-08): a "pre-provisioned, free, time-limited AWS account" with no credit card, **8 hours from activation, one per builder per week**, cleaned up automatically. It is only available from "select workshops" **[Doc]** ([AWS What's New](https://aws.amazon.com/about-aws/whats-new/2026/07/aws-builder-center-sandbox/)).
- **KodeKloud's AWS playground** is the only sandbox that documents EKS and RDS PostgreSQL. Its caps are tight: 256m / 512Mi per pod, 3 pods per namespace, 2 vCPU / 4 GiB per cluster, t2/t3 up to medium, Single-AZ RDS on T-class up to 30 GB **[Doc]** ([KodeKloud playground](https://kodekloud.com/playgrounds/aws)). Sessions last 3 hours and nothing is saved **[Anecdotal]** ([KodeKloud community](https://kodekloud.com/community/t/how-long-i-can-use-the-aws-playground-once-i-loggedin/141259)).
- **Pluralsight** gives 4-hour sandboxes in us-east-1 and us-west-2. Its EKS row could not be read **[Secondary]** ([Pluralsight AWS sandbox](https://help.pluralsight.com/hc/en-us/articles/24425443133076-AWS-cloud-sandbox)).
- **Skill Builder labs** are guided labs, and the subscription is about $29/month **[Secondary]** ([Skill Builder pricing](https://aws.amazon.com/training/digital/pricing/?nc1=h_ls)).

Three unknowns gate every sandbox:

- No source confirms that any of them allows `iam:CreateOpenIDConnectProvider`.
- None confirms that a full OpenTofu apply of this stack fits in one session.
- None says whether CLI credentials usable by OpenTofu are issued. KodeKloud does not mention ElastiCache at all.

Credit programs do not solve the problem. Community Builders (~$500 a year, member-reported), Open Source credits and Activate are all redeemed onto an account the applicant owns, so they reduce spend but leave the uncapped account exposed **[Secondary]** ([Classmethod, 2026-06-28](https://dev.classmethod.jp/en/articles/aws-community-builders-credit-usage/); [AWS Activate](https://startups.aws.com/lp/aws-activate-credits)). Other clouds lose the AWS story. The GCP trial does not bill until a manual upgrade, but it needs a card and gives GKE, not EKS, IRSA or RDS **[Doc]** ([Google Cloud free features](https://docs.cloud.google.com/free/docs/free-cloud-features)).

No credible source was found on how hiring managers weigh emulator evidence against real-cloud evidence. The project's three-level evidence label is itself what makes the difference legible, and a few dated real-sandbox runs would upgrade the strongest claims **[Inference]**.

## No free host keeps an arm64 shop running all the time

GitHub's `ubuntu-24.04-arm` runner remains the best Kubernetes host. It has 4 CPUs, 16 GB RAM and a 14 GB SSD, use of standard runners is "free and unlimited on public repositories", it has passwordless sudo, and jobs are capped at 6 hours **[Doc]** ([GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners); [Actions limits](https://docs.github.com/en/actions/reference/limits)). Without a payment method, Actions usage beyond quota is blocked rather than billed **[Doc]** ([Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)), so charges are impossible. The 14 GB disk is a tighter limit than RAM once 11 images, the k3s node image and Argo CD are loaded **[Inference]**. Nobody has published kind or k3s on the arm runner's cgroup setup, so D31's first workflow should assert `docker info` shows cgroup v2 **[Inference]**.

**Watch out:** GitHub's terms limit Actions to activity related to "the production, testing, deployment, or publication" of the project and forbid offering a "stand-alone or integrated application or service" **[Doc]** ([GitHub additional product terms](https://docs.github.com/en/site-policy/github-terms/github-terms-for-additional-products-and-features)). A short, attended demo arguably counts as publication. Looping runner jobs to keep a public shop always on is the pattern those clauses target, and the risk is account suspension, not a bill **[Inference]**. One blog claims GitHub scans for tunnelling binaries, but it cites no GitHub source **[Anecdotal]** ([DevActivity](https://devactivity.com/insights/github-actions-and-tor-why-free-hosting-attempts-lead-to-account-bans)).

Oracle's OKE is the only free managed control plane with an arm64 node pool, and 2026 made it worse. Always Free A1 is now "equivalent to 2 OCPUs and 12 GB of memory" per tenancy **[Doc]** ([OCI Always Free](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)). The cut took effect on 2026-06-15, halving the old 4 OCPU / 24 GB without a customer notice **[Secondary]** ([InfoQ](https://www.infoq.com/news/2026/07/oracle-cloud-free-tier-limits/)). Over-limit instances are disabled and later deleted **[Doc]** ([OCI Free Tier](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm)). Idle A1 instances can be reclaimed below a 20% p95 utilisation **[Doc]**. Whether an un-upgraded Free Tier tenancy can create OKE clusters at all is undocumented, PAYG limits are contested, and signup needs a card **[Secondary]**/**[Doc]**.

The roughly 8 GB stack fits on a single 12 GB node only tightly. Floci's "EKS" would also no longer be the cluster serving traffic, which breaks the coherence of "OpenTofu built this EKS" **[Inference]**. The other free options are worse:

- **Red Hat's Developer Sandbox** needs no card, but its pods are deleted after 12 hours and it gives no cluster-admin **[Doc]** ([Red Hat Sandbox FAQ](https://developers.redhat.com/developer-sandbox/faq)). Its architecture is probably x86, which would not run arm64-only images **[Inference]**.
- **Codespaces** gives 120 core-hours a month on Free, roughly 30 hours on a 4-core machine, and is blocked rather than billed without a card. Its terms forbid "production-facing" hosting **[Doc]** ([Codespaces billing](https://docs.github.com/en/billing/concepts/product-billing/github-codespaces)).
- **GCP and Azure** free compute is in the 1 GB class **[Doc]** ([Google Cloud free features](https://docs.cloud.google.com/free/docs/free-cloud-features); [Azure free services](https://azure.microsoft.com/en-us/pricing/free-services)).

The honest answer to "can it be always on?" is no, not without accepting OCI's card and fragility. The always-on surface should stay what D36 already says it is, the static Vercel showcase. The live demo stays a short, attended run of the same workflow that gates merges.

| Kubernetes host | Fits ~8 GB arm64 stack | Always on | Charge risk | AWS realism | Fit |
|---|---|---|---|---|---|
| **GitHub `ubuntu-24.04-arm` (public repo)** | Yes, 16 GB (disk tight) | No, ≤6 h jobs | Impossible [Doc] | Same k3s Floci builds | **Best: CI, verification, demo** |
| Oracle OKE Basic + A1 | Barely, 12 GB per tenancy | Yes, but reclamation and capacity risk | Card; avoidable charges; PAYG limits disputed [Doc]/[Secondary] | Real managed control plane, but OCI APIs | Owner decision; not recommended |
| Red Hat Developer Sandbox | RAM yes; arm64 probably no | Pods die every 12 h | Impossible, no card [Doc] | Poor (OpenShift, no admin) | Unfit |
| GitHub Codespaces | 16 GB on 4-core, x86 | No, ~30 h/month | Impossible without card [Doc] | None | Dev only, wrong architecture |
| Claude Code cloud session | 15 GiB, x86, cgroup v1 | No, per-session | None | Static checks only | API layer and offline checks |
| GKE trial / AKS | Yes (credits) | 90 days / 30 days | Card; GKE trial cannot auto-bill [Doc] | Not AWS | Fallback only |

## The workbench should validate manifests, not run the cluster

The cloud session is a poor place for Kubernetes, and the cause is specific. This VM mounts **cgroup v1** (`/sys/fs/cgroup` is tmpfs with v1 controllers, and Docker reports `Cgroup Version: 1`), boots with `nomodule`, has no IP_VS, and its conntrack sysctl writes fail **[Observed]**.

Since Kubernetes v1.35, `failCgroupV1` defaults to true, so kubelet refuses to start on cgroup v1. Version 1.36 keeps the opt-out as a fallback, and that fallback "is scheduled for removal in Kubernetes v1.38" **[Doc]** ([Kubernetes blog, 2026-10-06](https://kubernetes.io/blog/2026/10/06/kubernetes-cgroups-v2-shift/)). The KEP says "no earlier than 1.38" **[Doc]** ([KEP-5573](https://kubernetes.dev/resources/keps/5573)). kind v0.31 node images have already dropped cgroup v1 **[Secondary]** (release notes read via mirror), and rootless k3s needs pure cgroup v2 **[Doc]** ([k3s advanced](https://docs.k3s.io/advanced)).

k3s 1.36 does become Ready with `--kubelet-arg=fail-cgroupv1=false` **[Observed]** (this session's partial run). kube-proxy's `--conntrack-max-per-core=0` is the documented way to avoid the sysctl write **[Doc]** ([kube-proxy reference](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/)). Image pulls need the proxy and CA passed into containerd, or pre-loaded images. `registry.k8s.io` and `quay.io`, where Argo CD's image lives, are not on the Trusted allowlist **[Doc]** ([Cloud environments](https://code.claude.com/docs/en/cloud-environments)). On top of that the VM is x86_64 **[Doc]**, so the arm64-only images (D27) would need QEMU binfmt emulation, and nobody has benchmarked it here **[Doc]** ([tonistiigi/binfmt](https://hub.docker.com/r/tonistiigi/binfmt)). Whether Floci's own k3s container can be handed the cgroup flag is undocumented **[Inference]**.

The durable split is to keep the session on Floci's AWS APIs and the three roots, which stage 1 already plans, plus offline rendering: `kustomize build` or `helm template` piped into `kubeconform -strict` with CRD schemas. Floci's EKS mock mode (`FLOCI_SERVICES_EKS_MOCK=true`) is the fallback if real-mode k3s fails here **[Doc]** ([Floci EKS docs](https://raw.githubusercontent.com/floci-io/floci/main/docs/services/eks.md)). The question "does it actually deploy" belongs on the arm runner. This matches stage 1's existing note that the shop is proved in stage 2. The k3s workaround is worth keeping only as a documented experiment with an expiry date.

## Backups belong on GitHub, encrypted, with a measured drill

GitHub is the only verified store that **cannot bill**. Without a payment method, Actions and Packages usage beyond quota "is blocked". Artifacts in a public repo last at most **90 days**. GHCR storage is "currently free", with a month's notice before any change **[Doc]** ([Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions); [retention](https://docs.github.com/en/organizations/managing-organization-settings/configuring-the-retention-period-for-github-actions-artifacts-and-logs-in-your-organization); [Packages billing](https://docs.github.com/en/billing/concepts/product-billing/github-packages)). Because everything from a public repo is public, every dump must be encrypted client-side, for example with `age` to a public key committed in git and the private key held in an environment secret **[Inference]**.

Cloudflare R2 has a generous free tier: 10 GB-month, 1M Class A and 10M Class B requests, and free egress **[Doc]** ([R2 pricing](https://developers.cloudflare.com/r2/pricing/)). But it requires completing "the checkout flow to add an R2 subscription" **[Doc]** ([R2 get started](https://developers.cloudflare.com/r2/get-started/)), and recent reports say a payment method is needed **[Anecdotal]**. Its budget alerts "do not pause or cap usage" **[Doc]** ([Cloudflare budget alerts](https://developers.cloudflare.com/billing/manage/budget-alerts/)). R2 also implements neither S3 versioning nor Object Lock, only its own removable bucket locks **[Doc]** ([R2 S3 compatibility](https://developers.cloudflare.com/r2/api/s3/api/); [bucket locks](https://developers.cloudflare.com/r2/buckets/bucket-locks/)).

The owner already registered `yaafsome.fyi` on Cloudflare Registrar, so a payment method is probably already on that Cloudflare account. That makes R2's card question moot and its billing question live **[Inference]** (PLAN.md D38). The realistic overrun is a runaway write loop, not storage. R2 therefore earns its place only if the project later wants continuous WAL archiving (WAL-G supports S3-compatible endpoints **[Doc]**, [WAL-G storages](https://wal-g.readthedocs.io/STORAGES/)). That buys little when environments live under 6 hours **[Inference]**.

The drill should be simple and produce numbers. The backup job and the restore job are:

1. **Back up** on a schedule and as a mandatory final step before teardown: `pg_dump -Fc` for orders, plus an RDB copy for carts. Redis documents RDB copying as "completely safe while the server is running" **[Doc]** ([Redis persistence](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/)). Encrypt the dumps and upload them with a timestamp and a `latest` pointer.
2. **Restore** after the environment is rebuilt from git: download, decrypt, `pg_restore`, and load the RDB before the cache starts.

Measurement uses a canary. Write a timestamped canary row and key just before the "disaster"; **RPO** is the canary time minus the newest restored timestamp. **RTO** is the wall-clock time from the job start to the first successful synthetic order through the restored shop. Stage 2 already records time-to-healthy, so RTO extends an existing metric. Planned teardowns give a near-zero RPO. Unplanned runner death bounds RPO by the backup interval. Carts can defensibly take the looser target **[Inference]**.

A planted fault, either a corrupt or a missing `latest` backup, must make the drill fail loudly. Two things are untested: whether `pg_dump` and `redis-cli` can reach Floci's RDS and ElastiCache containers, and that Floci's ElastiCache is Valkey, so RDB compatibility needs checking **[Inference]**.

The real-AWS production design stays on paper with a Pricing Calculator estimate:

- **RDS PITR:** transaction logs are uploaded "every five minutes" **[Doc]** ([RDS PITR](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIT.html)).
- **AWS Backup:** copy to a second Region, with Vault Lock in compliance mode, which "cannot be changed or deleted by any user or by AWS" **[Doc]** ([Vault Lock](https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html)).
- **ElastiCache:** snapshots to S3 **[Doc]** ([ElastiCache backups](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/backups.html)).

Orders should store only an opaque payment token, never a PAN. That keeps the database and its backups outside the cardholder data environment **[Secondary]** ([Stripe on tokenization](https://stripe.com/resources/more/pci-compliance-tokenization)). A Luhn-pattern check on seed data and backups would turn the claim into verified evidence.

## What changes and what stays

| Component | Best fit (October 2026) | Evidence | Change from current design |
|---|---|---|---|
| AWS API layer (VPC, EKS, RDS, ElastiCache, IAM, ECR, ALB) | Floci 2.2, pinned by digest | [Doc] | Keep (D22). Turn on `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED` in CI and stop using the `test` key; label ALB "API-level" and Redis as Valkey |
| IaC | Three OpenTofu roots | [Observed] | Keep. Prove `use_lockfile` on Floci with two concurrent applies (planted fault) |
| Kubernetes + Argo CD | Floci's k3s on `ubuntu-24.04-arm` | [Doc] | Keep (D31). Assert cgroup v2 and disk headroom in the workflow |
| Real-AWS evidence | Vendor sandbox, time-boxed: Builder Center first, KodeKloud if the owner pays | [Doc]/[Inference] | **New lane**: a spike to test OIDC provider creation, EKS, RDS and credentials; each run recorded with date, logs and teardown proof |
| IAM-only lane on own account | Rejected (D20) | [Doc] | No change; no hard cap exists for this account |
| Workbench | Cloud session: Floci APIs, `tofu plan`, kustomize + kubeconform | [Observed] | Treat k3s-in-session as an experiment with an expiry date (Kubernetes ≥1.38) |
| Live demo | Attended, ≤6 h run through the named tunnel and Access | [Doc] | Keep (D33). Never loop jobs to fake always-on; add a recorded walkthrough |
| Always-on surface | Vercel static showcase | [Observed] | Keep (D36) |
| Backups | `age`-encrypted dumps to GHCR (ORAS) or artifacts | [Doc]/[Inference] | **Decide** GitHub over R2; add final-backup-on-teardown and the canary RPO/RTO drill |
| Production DR | RDS PITR, AWS Backup cross-Region with Vault Lock | [Doc] | Designed only, with a Pricing Calculator estimate |

| Risk | Likelihood / impact | Mitigation |
|---|---|---|
| A Floci breaking change or an abandoned project | Medium / high | Digest pins, a release-train watch, MIT fork as a fallback [Inference] |
| A reviewer over-reads Floci claims (IAM, isolation, ALB, multi-AZ, backups) | High / medium | A claims table with evidence labels; IAM enforcement on in CI [Inference] |
| GitHub flags tunnel demos as hosting | Low / high (account suspension) | Attended, time-boxed demos only [Doc]/[Inference] |
| A sandbox blocks OIDC or EKS, or times out before apply finishes | High / low | A spike before any commitment; trimmed manifests for KodeKloud [Inference] |
| Leaked credential on the owner's account | Low / very high | No access keys anywhere; no real-AWS lane (D20) [Secondary] |
| The arm runner's 14 GB disk overflows | Medium / medium | Pre-clean, small images, measure [Inference] |
| The cloud-session k3s path breaks | Certain over time | Static checks in session; deploy proof on runners [Doc] |
| Backup encryption key lost or exposed | Low / high | Key only in the environment secret, offline copy kept by the owner [Inference] |

## Conclusion

The question was never "emulator or real cloud". It is which kind of evidence each layer can honestly carry. Floci carries the continuous, every-PR proof that the infrastructure and GitOps loop converge from nothing, and it does so at a cost that is structurally zero. A borrowed sandbox can carry occasional, dated proof that the same OpenTofu meets real AWS validation, quotas and timing. The owner's own account carries nothing, because AWS's first real hard cap arrived in September 2026 and only for new sign-ups. The project's strongest differentiator is therefore not any single host. It is the discipline of labelling each claim with the lane that proved it, with a planted fault behind each check, so that turning on IAM enforcement and proving the S3 lock become higher-value work than finding a cluster that is always on.

Six things need the owner's decision:

1. Whether to request a Builder Center sandbox from an eligible EKS or Argo CD workshop, and, if that fails, whether to pay for a KodeKloud or Pluralsight subscription. Either needs a card, but never on AWS.
2. Whether GitHub (GHCR or artifacts, encrypted) is accepted as the backup store over R2, given that the Cloudflare account probably already holds a card.
3. Whether OCI's always-on option is closed for good.
4. Whether D20 is revisited once the project is complete.
5. Whether a recorded demo is an acceptable substitute for a standing one.
6. Which RPO targets the architecture track sets for orders and for carts.
