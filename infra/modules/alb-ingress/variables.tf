variable "name" {
  description = "Name prefix for the load balancer and target group."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Subnets the load balancer is placed in."
  type        = list(string)
}

variable "target_host" {
  description = "What the target group sends traffic to: an IP address on real AWS; on Floci, the cluster node's container name, which Docker DNS resolves on the shared network."
  type        = string
}

variable "target_port" {
  description = "The ingress controller's NodePort on the target."
  type        = number
}

variable "listener_port" {
  description = "Port the load balancer listens on."
  type        = number
  default     = 8080
}

variable "tags" {
  type    = map(string)
  default = {}
}
