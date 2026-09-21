provider "aws" {
  region = var.region

  access_key = "test"
  secret_key = "test"

  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    ec2 = var.floci_endpoint
    sts = var.floci_endpoint
    iam = var.floci_endpoint
    eks = var.floci_endpoint
    ecr = var.floci_endpoint
    s3  = var.floci_endpoint
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name = "${var.project}-floci"

  tags = {
    Project     = var.project
    Environment = "floci"
  }
}

module "eks" {
  source = "../../modules/eks-cluster"

  name       = "${var.project}-floci"
  subnet_ids = module.vpc.private_subnet_ids

  tags = {
    Project     = var.project
    Environment = "floci"
  }
}

module "ecr" {
  source = "../../modules/ecr"

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

  tags = {
    Project     = var.project
    Environment = "floci"
  }
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  name_prefix         = var.project
  github_repository   = "ya11so22/yaaf-project"
  ecr_repository_arns = values(module.ecr.repository_arns)

  tags = {
    Project     = var.project
    Environment = "floci"
  }
}

# Floci's EKS auth webhook rejects the public test/test key pair and needs a real IAM key, so
# `kubectl` authenticates as this user. Managed here, not by a script, so it is created once and
# reconciled like everything else (ADR-0014). The secret lives only in the local, git-ignored
# state of this emulator environment.
resource "aws_iam_user" "kubectl" {
  name = "${var.project}-kubectl"

  tags = {
    Project     = var.project
    Environment = "floci"
  }
}

resource "aws_iam_access_key" "kubectl" {
  user = aws_iam_user.kubectl.name
}
