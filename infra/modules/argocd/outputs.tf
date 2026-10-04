output "namespace" {
  value = helm_release.argocd.namespace
}

output "root_application" {
  description = "The one Application OpenTofu creates; it creates the rest from deploy/apps."
  value       = "platform"
}
