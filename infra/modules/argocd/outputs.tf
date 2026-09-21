output "namespace" {
  value = helm_release.argocd.namespace
}

output "applications" {
  value = keys(var.applications)
}
