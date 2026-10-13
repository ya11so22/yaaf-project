terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # No backend yet. This root creates the state bucket that the other roots will use, so its own state starts local
  # (the same reasoning as infra/environments/dev/bootstrap, PLAN.md D22). Keeping that one file safe is a runbook step:
  # after the bucket exists it is migrated into the bucket (docs/guides/real-aws-account.md, once written).
}
