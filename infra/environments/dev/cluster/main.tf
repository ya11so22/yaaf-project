# The third dev root (ADR-0022, ADR-0023): what runs inside the EKS cluster that ../foundation creates. A separate
# root because the Helm provider needs a cluster that already exists to connect to; ../foundation must be applied
# first and the kubeconfig written (scripts/dev-up.ps1 does both, in order).
provider "helm" {
  kubernetes = {
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = var.kubeconfig_context
  }
}

provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kubeconfig_context
}

module "argocd" {
  source = "../../../modules/argocd"

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

    # Traefik, the ingress controller behind the ALB (ADR-0022). A NodePort service on 30080, which is
    # what the ALB's target group points at. The Ingress status address is set to "localhost": with a
    # NodePort service there is no load-balancer address for Traefik to copy, and Argo CD reports an
    # Ingress Progressing until it has one.
    "traefik" = {
      namespace = "traefik"
      source = {
        repoURL        = "https://traefik.github.io/charts"
        chart          = "traefik"
        targetRevision = "41.6.0"
        helm = {
          valuesObject = {
            service = { spec = { type = "NodePort" } }
            ports = {
              web       = { nodePort = 30080 }
              websecure = { expose = { default = false } }
            }
            providers = {
              kubernetesIngress = {
                publishedService = { enabled = false }
                ingressEndpoint  = { hostname = "localhost" }
              }
            }
          }
        }
      }
    }

    # The Ingress objects for the platform tools, from git. The shop's own Ingress is part of deploy/dev.
    "platform-ingress" = {
      namespace = "traefik"
      source = {
        repoURL        = "https://github.com/ya11so22/yaaf-project.git"
        targetRevision = var.target_revision
        path           = "deploy/ingress"
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
    #
    # There is no login screen: every visitor is served as Headlamp's own read-only service account.
    # A token login cannot survive a cluster reset (the new cluster has new signing keys, so every old
    # token stops validating). Headlamp calls this option unsafe because anyone who can reach the UI
    # gets that account's access; here that is read-only without secrets, and the only way in is the
    # loopback-only ALB (ADR-0022). Do not carry this to anything reachable by others.
    "headlamp" = {
      namespace = "headlamp"
      source = {
        repoURL        = "https://kubernetes-sigs.github.io/headlamp/"
        chart          = "headlamp"
        targetRevision = "0.45.0"
        helm = {
          valuesObject = {
            clusterRoleBinding = { clusterRoleName = "headlamp-viewer" }
            config             = { unsafeUseServiceAccountToken = true }
          }
        }
      }
    }
  }
}
