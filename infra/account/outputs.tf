output "state_bucket_name" {
  description = "The bucket the other roots keep their state in (PLAN.md D22, reworked for the real account)."
  value       = aws_s3_bucket.state.bucket
}

output "boundary_arn" {
  description = "The permissions boundary every principal created through the deployer must carry."
  value       = aws_iam_policy.boundary.arn
}

output "boundary_policy" {
  description = "The boundary's policy document, exposed so the tests can read it."
  value       = local.boundary_policy
}

output "deployer_role_arn" {
  description = "The role the owner's CloudShell applies assume (PLAN.md D56)."
  value       = aws_iam_role.deployer.arn
}
