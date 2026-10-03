# Argo CD, installed from the official chart, plus one Application for the workload (ADR-0023).
# Nothing pushes the workload into the cluster: Argo CD reconciles it from git with automated
# sync, pruning and self-heal.
#
# Two releases, in order, on purpose: the Application is a custom resource, and Helm cannot create
# one in the same release that installs its CRD ("no matches for kind Application"). The argo-cd
# chart installs the CRDs; the companion argocd-apps chart, which Argo's project publishes for this,
# then creates the Application once they exist.
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

resource "helm_release" "applications" {
  name      = "argocd-apps"
  namespace = var.namespace

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.apps_chart_version

  depends_on = [helm_release.argocd]

  values = [yamlencode({
    applications = {
      for name, app in var.applications : name => {
        namespace = var.namespace
        # Deleting the Application removes what it deployed.
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        project    = "default"
        source     = app.source
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = app.namespace
        }
        syncPolicy = {
          automated   = { prune = true, selfHeal = true }
          syncOptions = ["CreateNamespace=true"]
        }
      }
    }
  })]
}
