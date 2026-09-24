variable "bucket_name" {
  description = "Name of the private bucket that holds the site's files."
  type        = string
}

variable "objects" {
  description = "Files to upload, keyed by object key (for example index.html), each with its content and content type."
  type = map(object({
    content      = string
    content_type = string
  }))
}

variable "comment" {
  description = "Description shown on the CloudFront distribution."
  type        = string
  default     = ""
}

variable "viewer_protocol_policy" {
  description = <<-EOT
    How CloudFront treats plain HTTP: redirect-to-https (the right choice on real AWS), https-only, or allow-all.
    The local Floci environment uses allow-all, because its CloudFront endpoint is served over plain HTTP.
  EOT
  type        = string
  default     = "redirect-to-https"

  validation {
    condition     = contains(["redirect-to-https", "https-only", "allow-all"], var.viewer_protocol_policy)
    error_message = "viewer_protocol_policy must be redirect-to-https, https-only or allow-all."
  }
}

variable "force_destroy" {
  description = "Delete the bucket even if it still holds files (true for disposable environments)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to every resource this module creates that supports them."
  type        = map(string)
  default     = {}
}
