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
  description = "Public key (one line, ssh-ed25519 ...) to import as the workstation's key pair. scripts/dev-up.ps1 passes the one it generates. Empty skips the key pair."
  type        = string
  default     = ""
}
