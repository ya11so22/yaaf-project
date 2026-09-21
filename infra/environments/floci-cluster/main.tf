# What runs inside the EKS cluster that ../floci creates (ADR-0013). A separate root because the
# Helm provider needs a cluster that already exists to connect to; ../floci must be applied first
# and the kubeconfig written (scripts/dev-up.ps1 does both, in order).
provider "helm" {
  kubernetes = {
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = "arn:aws:eks:${var.region}:000000000000:cluster/${var.cluster_name}"
  }
}

module "argocd" {
  source = "../../modules/argocd"

  repo_url        = "https://github.com/ya11so22/yaaf-project.git"
  target_revision = var.target_revision

  app_name      = "online-boutique-dev"
  app_path      = "deploy/dev"
  app_namespace = "boutique"
}
