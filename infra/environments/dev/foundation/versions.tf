terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State lives in the bucket the bootstrap root creates, on Floci (ADR-0022). use_lockfile is OpenTofu's native S3
  # locking: a .tflock object next to the state, so two applies cannot run at once. No DynamoDB table is needed.
  # CI replaces this block with a local backend through an override file (.github/workflows/infra.yml).
  backend "s3" {
    bucket       = "yaaf-dev-tfstate"
    key          = "foundation/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true

    endpoints = {
      s3 = "http://localhost:4566"
    }
    use_path_style              = true
    access_key                  = "test"
    secret_key                  = "test"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
  }
}
