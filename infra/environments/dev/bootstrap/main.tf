# The first of the three dev roots (ADR-0022): the S3 bucket that holds the OpenTofu state of the other two.
# Its own state is a local file, because a bucket cannot hold the state of the code that creates it. This is
# the same "bootstrap" step real teams run once per AWS account.
provider "aws" {
  region = var.region

  # Floci accepts any credentials. Static test keys, with the endpoint below, also mean this code can never
  # reach real AWS by accident, whatever is in ~/.aws.
  access_key = "test"
  secret_key = "test"

  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3  = var.floci_endpoint
    sts = var.floci_endpoint
  }
}

resource "aws_s3_bucket" "state" {
  bucket = "${var.project}-dev-tfstate"

  # State is the one thing that must not be deleted by a typo. A full reset deletes Floci's data instead
  # (scripts/dev-down.ps1 -Reset).
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project     = var.project
    Environment = "dev"
    Purpose     = "opentofu-state"
  }
}

# Versioning keeps every earlier state file, so a bad apply can be rolled back by restoring a version.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# State files contain secrets (for example the kubectl user's access key), so encrypt at rest.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
