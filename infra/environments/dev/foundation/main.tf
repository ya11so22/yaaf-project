# The second dev root (PLAN.md D22): the account-level infrastructure on the local AWS. Network, EKS, registry, IAM,
# the ingress load balancer. What runs inside the cluster is the cluster root's job.
provider "aws" {
  region = var.region

  # Floci accepts any credentials. Static test keys, with the endpoints below, also mean this code can never
  # reach real AWS by accident, whatever is in ~/.aws.
  access_key = "test"
  secret_key = "test"

  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # Every service this root calls must be listed; an unlisted one would go to the real AWS endpoint (and fail,
  # with the test keys above).
  endpoints {
    ec2   = var.floci_endpoint
    ecr   = var.floci_endpoint
    eks   = var.floci_endpoint
    elbv2 = var.floci_endpoint
    iam   = var.floci_endpoint
    s3    = var.floci_endpoint
    sts   = var.floci_endpoint
  }

  # Applied to every resource that supports tags, so modules do not each need them passed in.
  default_tags {
    tags = {
      Project     = var.project
      Environment = "dev"
      ManagedBy   = "opentofu"
    }
  }
}

locals {
  name = "${var.project}-dev"
}

module "vpc" {
  source = "../../../modules/vpc"

  name = local.name
}

module "eks" {
  source = "../../../modules/eks-cluster"

  name               = local.name
  subnet_ids         = module.vpc.private_subnet_ids
  kubernetes_version = var.kubernetes_version
}

module "ecr" {
  source = "../../../modules/ecr"

  name_prefix = var.project
  repositories = [
    "adservice",
    "cartservice",
    "checkoutservice",
    "currencyservice",
    "emailservice",
    "frontend",
    "loadgenerator",
    "paymentservice",
    "productcatalogservice",
    "recommendationservice",
    "shippingservice",
    "shoppingassistantservice",
  ]

  force_delete = true
}

# The roles GitHub Actions would assume on real AWS (PLAN.md D6). Floci stores them faithfully but does not enforce
# their trust conditions, so here they prove the code's shape, not its security (PLAN.md D20 covers the real test).
module "github_oidc" {
  source = "../../../modules/github-oidc"

  name_prefix         = var.project
  github_repository   = var.github_repository
  ecr_repository_arns = values(module.ecr.repository_arns)
}

# Floci's EKS authenticator rejects the public test/test key pair and needs a real IAM key, so kubectl (and the
# AWS CLI profile the `up` task writes) authenticate as this user. The secret lives only in the encrypted
# state in the S3 bucket on Floci.
resource "aws_iam_user" "kubectl" {
  name = "${var.project}-kubectl"
}

resource "aws_iam_access_key" "kubectl" {
  user = aws_iam_user.kubectl.name
}

# The entry point in front of the cluster: an ALB whose target is Traefik's NodePort on the cluster node. Traefik
# is installed by Argo CD from the cluster root. On Floci the target is the node's container name, which Docker
# DNS resolves on the shared network; on real AWS it would be an IP address.
module "ingress" {
  source = "../../../modules/alb-ingress"

  name        = local.name
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.public_subnet_ids
  target_host = "floci-eks-${module.eks.cluster_name}"
  target_port = 30080
}
