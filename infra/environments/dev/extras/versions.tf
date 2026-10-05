terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Same bucket as the other roots, its own key (ADR-0022). CI replaces this block with a local backend through an override
  # file only where it plans without Floci.
  backend "s3" {
    bucket       = "yaaf-dev-tfstate"
    key          = "extras/terraform.tfstate"
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
