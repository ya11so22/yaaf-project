output "argocd_namespace" {
  value = module.argocd.namespace
}

output "applications" {
  value = module.argocd.applications
}
