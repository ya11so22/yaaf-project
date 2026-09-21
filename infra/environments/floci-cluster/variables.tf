variable "project" {
  type    = string
  default = "yaaf"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  description = "The EKS cluster created by ../floci."
  type        = string
  default     = "yaaf-floci"
}

variable "kubeconfig_path" {
  description = "Kubeconfig that reaches the cluster. scripts/dev-up.ps1 writes it."
  type        = string
  default     = "~/.kube/config"
}

variable "target_revision" {
  description = "Git revision Argo CD tracks. A branch name to try a change before it is merged; a commit SHA in CI."
  type        = string
  default     = "main"
}
