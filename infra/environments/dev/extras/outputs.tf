output "workstation_instance_id" {
  description = "The instance to log in to. On Floci its container is floci-ec2-<id>."
  value       = module.workstation.instance_id
}
