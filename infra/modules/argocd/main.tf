# Argo CD, installed from the official chart, plus one Application for the workload (ADR-0013).
# Nothing pushes the workload into the cluster: Argo CD reconciles it from git with automated
# sync, pruning and self-heal. The Application is created by the chart itself (extraObjects) so it
# lands after the chart's CRDs in the same release.
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
      params = {
        # The UI and API are reached with `kubectl port-forward`, not through an ingress.
        "server.insecure" = true
      }
    }

    extraObjects = [{
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = var.app_name
        namespace = var.namespace
        # Deleting the Application removes what it deployed.
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
      }
      spec = {
        project = "default"
        source = {
          repoURL        = var.repo_url
          targetRevision = var.target_revision
          path           = var.app_path
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = var.app_namespace
        }
        syncPolicy = {
          automated   = { prune = true, selfHeal = true }
          syncOptions = ["CreateNamespace=true"]
        }
      }
    }]
  })]
}
