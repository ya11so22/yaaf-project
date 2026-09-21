output "argocd_namespace" {
  value = module.argocd.namespace
}

output "applications" {
  value = module.argocd.applications
}

# Read by scripts/dev-up.ps1 to register the GitHub webhook. A capability, so sensitive.
output "webhook_url" {
  value     = "https://smee.io/${random_id.smee_channel.hex}"
  sensitive = true
}
