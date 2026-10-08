variable "floci_endpoint" {
  description = "Base URL of the local Floci instance."
  type        = string
  default     = "http://localhost:4566"
}

variable "region" {
  description = "AWS region to target (Floci accepts any region string)."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Name prefix used for resources created in this environment."
  type        = string
  default     = "yaaf"
}

variable "github_repository" {
  description = "The GitHub repository (owner/name) allowed to assume the GitHub Actions roles."
  type        = string
  default     = "ya11so22/yaaf-project"
}

variable "ssh_public_key" {
  description = "Public key (one line, ssh-ed25519 ...) to import as the workstation's key pair. The `up` task passes the one it generates. Empty skips the key pair."
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "Kubernetes version of the EKS cluster. Set once in mise.toml and passed as TF_VAR_kubernetes_version (PLAN.md D25)."
  type        = string
}

variable "ingress_port" {
  description = "Host port the ingress listener is published on, for the links on the portal page. Set once in mise.toml (INGRESS_PORT)."
  type        = string
}
