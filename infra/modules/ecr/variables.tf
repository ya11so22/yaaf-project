variable "name_prefix" {
  description = "Prefix for every repository name, giving <prefix>/<service>."
  type        = string
}

variable "repositories" {
  description = "Service names to create one repository each for."
  type        = set(string)
}

variable "image_tag_mutability" {
  description = <<-EOT
    IMMUTABLE stops a tag being overwritten, so a deployed tag always means the same image
    (CI pushes per-commit tags). Use MUTABLE only if something needs a moving tag like latest.
  EOT
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Scan each pushed image for known vulnerabilities."
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Keep only this many most-recent images per repository; older ones expire."
  type        = number
  default     = 10
}

variable "force_delete" {
  description = "Delete repositories even if they still hold images (true for disposable environments)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to every resource this module creates."
  type        = map(string)
  default     = {}
}
