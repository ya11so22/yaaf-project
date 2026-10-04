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

variable "repo_url" {
  description = "The git repository Argo CD reconciles from. Its deploy/apps directory holds one Application file per thing Argo CD runs."
  type        = string
}

variable "target_revision" {
  description = "Git revision the root Application tracks, and the one every Application sourced from repo_url is pointed at. A branch name to try a change before it is merged."
  type        = string
  default     = "main"
}

variable "source_repos" {
  description = "Repositories the dev project may deploy from: repo_url and each Helm chart repository in use."
  type        = list(string)
}
