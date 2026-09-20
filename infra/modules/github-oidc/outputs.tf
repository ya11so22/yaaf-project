output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider the roles trust."
  value       = local.oidc_provider_arn
}

output "ecr_push_role_arn" {
  description = "Role for build workflows to push images."
  value       = aws_iam_role.ecr_push.arn
}

output "tofu_plan_role_arn" {
  description = "Read-only role for tofu plan on pull requests."
  value       = aws_iam_role.tofu_plan.arn
}

output "tofu_apply_role_arn" {
  description = "Write role for tofu apply, assumable only from the apply branch."
  value       = aws_iam_role.tofu_apply.arn
}
