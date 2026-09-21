variable "chart_version" {
  description = "Version of the argo-cd Helm chart (pinned; bump deliberately). 10.9.2 installs Argo CD v3.5.3."
  type        = string
  default     = "10.9.2"
}

variable "namespace" {
  description = "Namespace Argo CD is installed into."
  type        = string
  default     = "argocd"
}

variable "repo_url" {
  description = "Git repository Argo CD reconciles from."
  type        = string
}

variable "target_revision" {
  description = "Git revision Argo CD tracks: a branch name for dev, a commit SHA when CI verifies a pull request."
  type        = string
  default     = "main"
}

variable "app_name" {
  description = "Name of the Argo CD Application for the workload."
  type        = string
}

variable "app_path" {
  description = "Path in the repository holding the workload's kustomization."
  type        = string
}

variable "app_namespace" {
  description = "Namespace the workload is deployed into (created by Argo CD)."
  type        = string
}
