# Research: the owner's AWS account is a project in the "new AWS experience"

**Date:** 2026-10-13. **Why:** the owner corrected an assumption (the account is on the Free plan with its $100 credits, not
a paid plan with expired credits) and ran the Agent Toolkit setup file, which names the "new AWS experience". Every claim is
from AWS's own pages read on this date; AWS marks the experience as "released to a limited number of customers", so it may
change. A record: not rewritten later.

## What the new experience is

- A **project** is an AWS account inside an **AWS-managed Organization**. AWS writes and applies the service control
  policies (SCPs) and resource control policies (RCPs); the owner cannot change them
  ([managed policies](https://docs.aws.amazon.com/accounts/latest/reference/scps-and-rcps-for-projects.html)).
- **The Region is assigned, not chosen:** a US contact address gives `us-east-2`, Europe `eu-north-1`, Asia Pacific
  `ap-southeast-2`; the Region does not change if the contact address does
  ([project Regions](https://docs.aws.amazon.com/accounts/latest/reference/project-regions.html)). The owner reports the
  project is in `us-east-1`; the managed `RegionFloor` policy allows `us-east-1`, `us-west-2` and the selected Region, so
  the owner's statement is plausible. To confirm in AWS Settings, Project, Additional Info, Region, before the first apply.
- **Free Tier:** $100 sign-up credit plus up to $100 earned; ends at 6 months or when credits run out, then the owner must
  upgrade; upgrading is irreversible and applies to every project
  ([upgrade](https://docs.aws.amazon.com/accounts/latest/reference/upgrade-account.html)). The page does not say whether
  unused credits carry over.

## Services

The Free Tier list includes EKS, EC2, ECS, RDS, Aurora, ElastiCache, DynamoDB, ECR, VPC, Elastic Load Balancing, S3, Lambda,
EventBridge, SNS, SQS, KMS, Secrets Manager, Systems Manager, CloudWatch, Managed Service for Prometheus, AWS Backup, AWS
Budgets, Cost Explorer, Route 53, CloudFormation, CloudShell, WAF, ACM and the Well-Architected Tool. **Paid plan only:**
Fault Injection Service, Managed Streaming for Kafka, MemoryDB, Kinesis. **Not available until advanced features:**
Organizations, IAM Identity Center (creating an instance), Control Tower, Pricing Calculator, Managed Grafana, GuardDuty,
Security Hub, Shield, Access Analyzer, Transit Gateway, Site-to-Site VPN
([supported services](https://docs.aws.amazon.com/accounts/latest/reference/supported-services-sign-up-new.html)).

## What the managed SCPs deny (Free and Paid plans alike)

- `iam:*Provider*`: **no IAM identity providers, so no GitHub OIDC provider.** GitHub Actions cannot assume a role.
- `ec2:RequestSpotInstances` and `ec2:RunInstances` with `InstanceMarketType = spot`: **no Spot.**
- `sso:CreateInstance`, `organizations:LeaveOrganization`; creating or changing roles under `role/managed/`.
- `billing:*` and account-contact APIs (use AWS Settings and Cost Explorer instead).
- IAM groups, login profiles, aliases; Reserved Instance and Savings Plans purchases; Transit Gateway and VPN.
- Near a spend limit, compute creation (`eks:CreateCluster`, `ec2:RunInstances`, load balancers, NAT gateways) is denied.

Allowed and useful: IAM roles and users (outside `role/managed/`), and EKS Pod Identity, which needs no OIDC provider.

## The way out: activate advanced features

Requires the Paid plan first, and cannot be reversed
([activate advanced features](https://docs.aws.amazon.com/accounts/latest/reference/activate-advanced-features.html)).
Afterwards the owner administers the Organization that holds the project (the project becomes a member account), can create
member accounts, write their own SCPs and RCPs, enable other Regions, use an IAM Identity Center organization instance,
and sets a root email for the management account. **The spend limit is removed and cannot be created**; cost control is
Budgets, Cost Explorer and Cost Anomaly Detection. The managed `BlockOrgEscape` and `ProtectManagedRoles` policies remain.
Unconfirmed: that the Spot and identity-provider denials are lifted (the page says all services become accessible, and the
policy shown for activated accounts does not contain them).

## Tools that can be used now

- **AWS Knowledge MCP** (`https://knowledge-mcp.global.api.aws`): answers an MCP `initialize` with no credentials from a
  cloud session (checked 2026-10-13); five tools: `aws___search_documentation`, `aws___read_documentation`,
  `aws___list_regions`, `aws___get_regional_availability`, `aws___retrieve_skill`.
- **AWS CloudShell:** browser shell, free, already signed in as the console user, 1 GB persistent home per Region, Amazon
  Linux 2023 with git, make, pip, tmux, Node.js and Python
  ([CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)). A Kiro CLI is reachable by typing
  `q` in CloudShell, and AWS's CloudShell guide has a Kiro CLI section; no official "preinstalled" announcement was found
  (community report and the user guide only).
- **Agent Toolkit for AWS** (SigV4 route): `aws login`, then `aws configure agent-toolkit`; needs a signed-in identity and is
  per session in a cloud container ([setup file](https://github.com/aws/agent-toolkit-for-aws/blob/main/setup-instructions/setup.md)).
  The new-experience rules file `aws-starter-rules.md` uses the words "project" and "team member" and asks the agent to ask
  the user for a help level.

## Open

Whether unused credits survive the upgrade; whether Spot and OIDC are allowed after activation; whether a read-only team
member role exists in the new experience; what Kiro CLI in CloudShell can do with the owner's credentials.
