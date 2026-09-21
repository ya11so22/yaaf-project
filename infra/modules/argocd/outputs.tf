output "namespace" {
  value = helm_release.argocd.namespace
}

output "application" {
  value = var.app_name
}
