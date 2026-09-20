variable "name_prefix" {
  description = "Prefix for role names and for the IAM resources the apply role may manage."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the roles, as owner/name."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like owner/name, with no wildcards."
  }
}

variable "apply_branch" {
  description = "Branch whose workflow runs may assume the apply role."
  type        = string
  default     = "main"
}

variable "ecr_repository_arns" {
  description = "ARNs of the ECR repositories the ecr-push role may push to."
  type        = list(string)
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. AWS allows one per URL per account; set false and pass oidc_provider_arn if it already exists."
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "ARN of an existing GitHub OIDC provider, used when create_oidc_provider is false."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every resource this module creates."
  type        = map(string)
  default     = {}
}
