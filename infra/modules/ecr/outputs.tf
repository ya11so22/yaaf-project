output "repository_urls" {
  description = "Map of service name to repository URL."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_arns" {
  description = "Map of service name to repository ARN."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.arn }
}
