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
