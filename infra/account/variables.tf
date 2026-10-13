variable "region" {
  description = "The project's Region (PLAN.md D54). The owner's project is us-east-1; AWS's docs say a US contact address is assigned us-east-2, so confirm in AWS Settings before the first apply."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Name prefix for everything this root creates."
  type        = string
  default     = "yaaf"
}

variable "account_id" {
  description = "The 12-digit AWS account ID of the project. Needed to name the state bucket (S3 names are global) and to write the boundary's ARN. Not a secret, but it is read from AWS Settings, never guessed."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be exactly 12 digits."
  }
}

variable "deployer_trusted_principal_arn" {
  description = "The IAM user or role allowed to assume the deployer role: the owner's own identity for the interim CloudShell applies (PLAN.md D56). GitHub's OIDC role is added later, at stage 2, once the Free-plan blocks are checked."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:(user|role)/", var.deployer_trusted_principal_arn))
    error_message = "deployer_trusted_principal_arn must be an IAM user or role ARN in this account."
  }
}
