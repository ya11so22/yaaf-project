output "argocd_namespace" {
  value = module.argocd.namespace
}

output "root_application" {
  value = module.argocd.root_application
}
