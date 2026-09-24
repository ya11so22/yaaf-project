output "vpc_id" {
  value = module.vpc.vpc_id
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

# Read by scripts/dev-up.ps1 to write the `floci` AWS CLI profile that kubectl uses.
output "kubectl_access_key_id" {
  value = aws_iam_access_key.kubectl.id
}

output "kubectl_secret_access_key" {
  value     = aws_iam_access_key.kubectl.secret
  sensitive = true
}

output "ingress_dns_name" {
  value = module.ingress.dns_name
}

output "portal_domain_name" {
  description = "The portal's CloudFront domain. On Floci it is <ID>.cloudfront.localhost, served on port 4566."
  value       = module.portal.distribution_domain_name
}
