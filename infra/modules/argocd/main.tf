# Argo CD, installed from the official chart, plus an AppProject and ONE root Application (ADR-0026).
# Everything else Argo CD runs is an Application file in git under deploy/apps/, so the platform is delivered by pull request
# the same way the workload is. Nothing pushes into the cluster: Argo CD reconciles from git with automated sync, pruning and
# self-heal.
#
# Two releases, in order, on purpose: the project and the Application are custom resources, and Helm cannot create one in the
# same release that installs its CRD ("no matches for kind Application"). The argo-cd chart installs the CRDs; the companion
# argocd-apps chart, which Argo's project publishes for this, then creates the project and the root Application once they exist.
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  # Wait until Argo CD's own workloads are ready, so the caller can rely on it being up.
  wait    = true
  timeout = 600

  values = [yamlencode({
    # Not needed here: no SSO, no notifications. Fewer pods on a single-node emulator cluster.
    dex           = { enabled = false }
    notifications = { enabled = false }

    configs = {
      # Poll git every 60 seconds (the chart's default is 180) so a merge reaches the cluster within about a
      # minute, without a webhook (ADR-0023).
      cm = {
        "timeout.reconciliation" = "60s"
      }
      params = {
        # Plain HTTP inside the cluster: the UI is reached through the loopback-only ingress, which has no TLS
        # locally (ADR-0022).
        "server.insecure" = true
      }
    }
  })]
}

resource "helm_release" "root" {
  name      = "argocd-apps"
  namespace = var.namespace

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.apps_chart_version

  depends_on = [helm_release.argocd]

  values = [yamlencode({
    # The default project allows any source and any destination. `dev` allows only this repository and the chart
    # repositories in use, and only this cluster. Cluster-scoped kinds are allowed because the platform installs CRDs,
    # ClusterRoles and a GatewayClass.
    projects = {
      dev = {
        namespace = var.namespace
        # No colon-space in it: the chart prints the description unquoted, and YAML would read it as a mapping.
        description = "The dev environment, the workload and the platform tools"
        sourceRepos = var.source_repos
        destinations = [{
          server    = "https://kubernetes.default.svc"
          namespace = "*"
        }]
        clusterResourceWhitelist = [{
          group = "*"
          kind  = "*"
        }]
      }
    }

    applications = {
      platform = {
        namespace = var.namespace
        # Deleting the Application removes what it deployed.
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        project    = "dev"
        source = {
          repoURL        = var.repo_url
          targetRevision = var.target_revision
          path           = "deploy/apps"
          # Applications whose source is this repository carry the label yaaf/source=repo. Their targetRevision is set
          # here to the root's own revision, so `up --revision <branch>` tries a branch end to end (ADR-0026).
          kustomize = {
            patches = [{
              target = {
                kind          = "Application"
                labelSelector = "yaaf/source=repo"
              }
              patch = <<-EOT
                - op: replace
                  path: /spec/source/targetRevision
                  value: ${var.target_revision}
              EOT
            }]
          }
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = var.namespace
        }
        syncPolicy = {
          automated = { prune = true, selfHeal = true }
        }
      }
    }
  })]
}
