variable "chart_version" {
  description = "Version of the argo-cd Helm chart (pinned; bump deliberately). 10.9.2 installs Argo CD v3.5.3."
  type        = string
  default     = "10.9.2"
}

variable "apps_chart_version" {
  description = "Version of the argocd-apps Helm chart, which creates the Application (pinned; bump deliberately)."
  type        = string
  default     = "2.0.5"
}

variable "namespace" {
  description = "Namespace Argo CD is installed into."
  type        = string
  default     = "argocd"
}

variable "applications" {
  description = <<-EOT
    Argo CD Applications to create, keyed by name. Each value has:
      namespace: the namespace the workload is deployed into (created by Argo CD)
      source:    the Argo CD source block, either a git path
                 ({ repoURL, targetRevision, path }) or a Helm chart
                 ({ repoURL, chart, targetRevision, helm = { valuesObject = { ... } } })
    Every Application syncs automatically with pruning and self-heal.
  EOT
  type        = any
}
