variable "namespace" {
  description = "Namespace the relay runs in (must already exist)."
  type        = string
}

variable "smee_url" {
  description = "The smee.io channel URL. It is the only thing limiting who can post to the channel, so it is a sensitive value kept out of git."
  type        = string
  sensitive   = true
}

variable "target_url" {
  description = "Where the relay posts each event: Argo CD's webhook endpoint."
  type        = string
}

variable "smee_client_version" {
  description = "Version of the smee-client npm package (pinned; bump deliberately)."
  type        = string
  default     = "5.0.0"
}

variable "image" {
  description = "Node image the relay runs on, pinned by digest (Node 24.21.0). Bump deliberately."
  type        = string
  default     = "node@sha256:ebfe2f90462722a7a4de65e91990e97fe0d401c70e0e762c5b53302f905ec1c1"
}
