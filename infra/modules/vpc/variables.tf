variable "name" {
  description = "Name prefix applied to every resource this module creates."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = <<-EOT
    Availability zones to spread subnets across. Passed explicitly (not looked up via a data
    source) so this module behaves identically against Floci and real AWS regardless of each
    one's AZ inventory.
  EOT
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per availability zone, same order as var.availability_zones."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per availability zone, same order as var.availability_zones."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "single_nat_gateway" {
  description = <<-EOT
    true: one NAT gateway shared by all private subnets (cheaper, single point of failure,
    used for the local dev environment).
    false: one NAT gateway per AZ (real HA posture, not used here yet — see ADR-0022 on why
    cost/simplicity wins for this project).
  EOT
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource this module creates."
  type        = map(string)
  default     = {}
}
