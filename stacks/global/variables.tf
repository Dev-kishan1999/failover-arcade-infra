variable "project" {
  description = "Short project name, used as a prefix for resource names."
  type        = string
  default     = "failover-arcade"
}

variable "env" {
  description = "Environment name."
  type        = string
  default     = "prod"
}

variable "primary_region" {
  description = "Region where images are pushed."
  type        = string
}

variable "secondary_region" {
  description = "Region that receives replicated images."
  type        = string
}

variable "app_github_repo" {
  description = "Application repo allowed to push images, as owner/name."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.app_github_repo))
    error_message = "Use the form owner/name."
  }
}

variable "release_tag_pattern" {
  description = "Git tag pattern in the app repo that is allowed to push images."
  type        = string
  default     = "v*"
}

variable "untagged_image_retention_days" {
  description = "Days to keep untagged images before ECR removes them."
  type        = number
  default     = 7
}
