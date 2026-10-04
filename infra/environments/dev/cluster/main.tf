# The third dev root (ADR-0022, ADR-0026): Argo CD inside the EKS cluster that ../foundation creates, and nothing else.
# Every other thing the cluster runs is an Application file in deploy/apps, delivered by pull request. A separate root because
# the Helm provider needs a cluster that already exists to connect to; ../foundation must be applied first and the kubeconfig
# written (the `up` task does both, in order).
provider "helm" {
  kubernetes = {
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = var.kubeconfig_context
  }
}

module "argocd" {
  source = "../../../modules/argocd"

  repo_url        = "https://github.com/ya11so22/yaaf-project.git"
  target_revision = var.target_revision

  # What the dev project may deploy from: this repository and the Helm chart repositories deploy/apps uses.
  source_repos = [
    "https://github.com/ya11so22/yaaf-project.git",
    "https://traefik.github.io/charts",
    "https://kubernetes-sigs.github.io/headlamp/",
  ]
}
