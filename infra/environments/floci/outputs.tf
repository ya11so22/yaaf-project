output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "github_oidc_role_arns" {
  value = {
    ecr_push   = module.github_oidc.ecr_push_role_arn
    tofu_plan  = module.github_oidc.tofu_plan_role_arn
    tofu_apply = module.github_oidc.tofu_apply_role_arn
  }
}
