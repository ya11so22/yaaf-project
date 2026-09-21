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

  applications = {
    # The workload, reconciled from this repository.
    "online-boutique-dev" = {
      namespace = "boutique"
      source = {
        repoURL        = "https://github.com/ya11so22/yaaf-project.git"
        targetRevision = var.target_revision
        path           = "deploy/dev"
      }
    }

    # The read-only role Headlamp runs as, from git. Cluster-scoped, so the namespace is only where
    # Argo CD records the Application's resources.
    "headlamp-rbac" = {
      namespace = "headlamp"
      source = {
        repoURL        = "https://github.com/ya11so22/yaaf-project.git"
        targetRevision = var.target_revision
        path           = "deploy/headlamp-rbac"
      }
    }

    # A web UI for the cluster, from its official Helm chart (pinned). The chart binds its service
    # account to cluster-admin by default; it is bound to the read-only headlamp-viewer role instead
    # (deploy/headlamp-rbac): a dashboard should show status, not change anything.
    "headlamp" = {
      namespace = "headlamp"
      source = {
        repoURL        = "https://kubernetes-sigs.github.io/headlamp/"
        chart          = "headlamp"
        targetRevision = "0.45.0"
        helm = {
          valuesObject = {
            clusterRoleBinding = { clusterRoleName = "headlamp-viewer" }
          }
        }
      }
    }
  }
}
