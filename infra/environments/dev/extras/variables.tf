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

variable "ssh_public_key" {
  description = "Public key (one line, ssh-ed25519 ...) to import as the workstation's key pair. `up --extras` passes the one it generates in .ssh/. Empty skips the key pair: the instance is then reachable through SSM and the dashboard terminal only."
  type        = string
  default     = ""
}
