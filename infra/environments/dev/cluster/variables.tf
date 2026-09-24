variable "kubeconfig_path" {
  description = "Kubeconfig that reaches the cluster. scripts/dev-up.ps1 writes it."
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Kubeconfig context of the cluster ../foundation creates: its ARN, which `aws eks update-kubeconfig` uses as the name. scripts/dev-up.ps1 passes the real one."
  type        = string
  default     = "arn:aws:eks:us-east-1:000000000000:cluster/yaaf-dev"
}

variable "target_revision" {
  description = "Git revision Argo CD tracks. A branch name to try a change before it is merged; a commit SHA in CI."
  type        = string
  default     = "main"
}
