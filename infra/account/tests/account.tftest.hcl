# Offline tests for the account root. `mock_provider` replaces AWS, so these need no credentials and no network calls to AWS
# (OpenTofu 1.8+). They prove the configuration's intent, not AWS's behaviour: whether AWS enforces the boundary is checked
# on the real account, in the owner's CloudShell, and recorded there with a date.

mock_provider "aws" {}

variables {
  account_id                     = "123456789012"
  deployer_trusted_principal_arn = "arn:aws:iam::123456789012:user/owner"
}

run "state_bucket_is_locked_down" {
  command = plan

  # The mock invents ARNs; a permissions boundary needs a real-looking one, so the mock is told the boundary's ARN.
  override_resource {
    target = aws_iam_policy.boundary
    values = {
      arn = "arn:aws:iam::123456789012:policy/yaaf-tofu-boundary"
    }
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.state.block_public_acls && aws_s3_bucket_public_access_block.state.block_public_policy
    error_message = "The state bucket must block public ACLs and public policies."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.state.ignore_public_acls && aws_s3_bucket_public_access_block.state.restrict_public_buckets
    error_message = "The state bucket must ignore public ACLs and restrict public buckets."
  }

  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "The state bucket must keep versions, so a bad apply can be undone."
  }

  assert {
    condition     = [for r in aws_s3_bucket_server_side_encryption_configuration.state.rule : r.apply_server_side_encryption_by_default[0].sse_algorithm][0] == "AES256"
    error_message = "The state bucket must be encrypted at rest."
  }

  assert {
    condition     = [for r in aws_s3_bucket_ownership_controls.state.rule : r.object_ownership][0] == "BucketOwnerEnforced"
    error_message = "Object ownership must be enforced to the bucket owner, so ACLs cannot grant access."
  }

  assert {
    condition     = output.state_bucket_name == "yaaf-123456789012-tfstate"
    error_message = "The state bucket name must include the account ID, because S3 names are global."
  }
}

run "boundary_stops_escape" {
  command = plan

  # The mock invents ARNs; a permissions boundary needs a real-looking one, so the mock is told the boundary's ARN.
  override_resource {
    target = aws_iam_policy.boundary
    values = {
      arn = "arn:aws:iam::123456789012:policy/yaaf-tofu-boundary"
    }
  }

  assert {
    condition     = contains(jsondecode(output.boundary_policy).Statement[1].Action, "organizations:*") && contains(jsondecode(output.boundary_policy).Statement[1].Action, "account:*") && contains(jsondecode(output.boundary_policy).Statement[1].Action, "billing:*")
    error_message = "The boundary must deny Organizations, account and billing actions."
  }

  assert {
    condition     = jsondecode(output.boundary_policy).Statement[2].Effect == "Deny" && jsondecode(output.boundary_policy).Statement[2].Resource == output.boundary_arn
    error_message = "The boundary must deny changing or deleting itself."
  }

  assert {
    condition     = contains(jsondecode(output.boundary_policy).Statement[3].Action, "iam:CreateRole") && contains(jsondecode(output.boundary_policy).Statement[3].Action, "iam:CreateUser") && jsondecode(output.boundary_policy).Statement[3].Condition.StringNotEquals["iam:PermissionsBoundary"] == output.boundary_arn
    error_message = "New users and roles must be denied unless they carry this same boundary."
  }
}

run "deployer_is_capped_by_the_boundary" {
  command = plan

  # The mock invents ARNs; a permissions boundary needs a real-looking one, so the mock is told the boundary's ARN.
  override_resource {
    target = aws_iam_policy.boundary
    values = {
      arn = "arn:aws:iam::123456789012:policy/yaaf-tofu-boundary"
    }
  }

  assert {
    condition     = aws_iam_role.deployer.permissions_boundary == output.boundary_arn
    error_message = "The deployer role must carry the boundary, so AdministratorAccess cannot exceed it."
  }

  assert {
    condition     = jsondecode(aws_iam_role.deployer.assume_role_policy).Statement[0].Principal.AWS == "arn:aws:iam::123456789012:user/owner"
    error_message = "Only the owner's identity may assume the deployer role."
  }
}

run "rejects_a_malformed_account_id" {
  command = plan

  # The mock invents ARNs; a permissions boundary needs a real-looking one, so the mock is told the boundary's ARN.
  override_resource {
    target = aws_iam_policy.boundary
    values = {
      arn = "arn:aws:iam::123456789012:policy/yaaf-tofu-boundary"
    }
  }

  variables {
    account_id = "not-an-account"
  }

  expect_failures = [var.account_id]
}
