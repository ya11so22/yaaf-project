# The first root for the real AWS account (PLAN.md D55 to D57): a state bucket, and a deployer role that is itself capped by a
# permissions boundary. Nothing here is applied yet. Every resource is offline-testable with `tofu test` (tests/).
#
# Watch out: aws_s3_bucket.state has prevent_destroy, so a typo cannot delete the state; removing it on purpose is a
# deliberate two-step change, not an accident.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = "account"
      ManagedBy   = "opentofu"
    }
  }
}

locals {
  name = "${var.project}-tofu"

  state_bucket_name = "${var.project}-${var.account_id}-tfstate"
  boundary_name     = "${local.name}-boundary"
  boundary_arn      = "arn:aws:iam::${var.account_id}:policy/${local.boundary_name}"
  deployer_name     = "${local.name}-deployer"

  # Written with jsonencode, not a data source, so the policy is plain text the tests can read.
  #
  # The boundary is the ceiling on what the deployer can do, even with AdministratorAccess attached: an allow in the
  # identity policy grants nothing that this boundary forbids. Its job is to stop the deployer escalating itself.
  boundary_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowEverythingElse"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      },
      {
        # Leaving the Organization, changing the account or its billing is for the owner in AWS Settings, never a deployer.
        Sid      = "DenyAccountAndBilling"
        Effect   = "Deny"
        Action   = ["organizations:*", "account:*", "billing:*", "aws-portal:*"]
        Resource = "*"
      },
      {
        # The boundary itself cannot be removed, rewritten or deleted by the identity it limits.
        Sid    = "DenyChangingTheBoundary"
        Effect = "Deny"
        Action = [
          "iam:DeleteUserPermissionsBoundary",
          "iam:DeleteRolePermissionsBoundary",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicy",
          "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion",
        ]
        Resource = local.boundary_arn
      },
      {
        # Every user or role created through this deployer carries the same boundary, so none can act outside it.
        Sid    = "NewPrincipalsCarryTheBoundary"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:CreateRole",
          "iam:PutUserPermissionsBoundary",
          "iam:PutRolePermissionsBoundary",
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "iam:PermissionsBoundary" = local.boundary_arn
          }
        }
      },
    ]
  })
}

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning keeps every earlier state file, so a bad apply can be undone by restoring a version.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# State holds secrets (the RDS password, later), so it is encrypted at rest. SSE-S3 costs nothing; a customer-managed KMS
# key costs $1 a month and is a decision for later, not a default.
# Accepted until 2027-04-12 (review at stage 2a, PLAN.md D55): a customer-managed KMS key costs $1 a month and adds a key to
# manage. SSE-S3 is encrypted at rest with AWS-managed keys; move to KMS once the account is upgraded and its costs are known.
#trivy:ignore:AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_policy" "boundary" {
  name        = local.boundary_name
  description = "Ceiling for the OpenTofu deployer (PLAN.md D47, D56): no escape from the account, no unbounded principals"
  policy      = local.boundary_policy
}

resource "aws_iam_role" "deployer" {
  name                 = local.deployer_name
  permissions_boundary = aws_iam_policy.boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "OwnerOnly"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = var.deployer_trusted_principal_arn }
    }]
  })
}

# AdministratorAccess under the boundary: the deployer may build the whole project, and the boundary is what stops that from
# becoming more than the project. Narrowing this to the exact actions is a later step, once the roots are written.
resource "aws_iam_role_policy_attachment" "deployer_admin" {
  role       = aws_iam_role.deployer.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
