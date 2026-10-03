variable "name" {
  description = "Name of the instance, and prefix for its security group, role and instance profile."
  type        = string
}

variable "vpc_id" {
  description = "VPC the instance's security group is created in."
  type        = string
}

variable "subnet_id" {
  description = "Subnet the instance is launched in."
  type        = string
}

variable "ami_id" {
  description = <<-EOT
    Image to launch. On Floci this is one of its catalogue aliases (ami-amazonlinux2023), each backed by a Docker
    image. On real AWS look the current one up instead, for example from the public SSM parameter
    /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64.
  EOT
  type        = string
  default     = "ami-amazonlinux2023"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  description = "Key pair for SSH. Null launches an instance reachable only through SSM (or the console terminal)."
  type        = string
  default     = null
}

variable "ssh_ingress_cidrs" {
  description = "Source ranges allowed to reach port 22. Keep this to the smallest range that works."
  type        = list(string)
  default     = ["127.0.0.1/32"]
}

variable "user_data" {
  description = "Script run once at first boot."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
