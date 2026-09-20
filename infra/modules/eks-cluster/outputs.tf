output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_role_arn" {
  description = "ARN of the cluster IAM role."
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "ARN of the node group IAM role."
  value       = aws_iam_role.node.arn
}
