variable "project" {
  description = "Short project name, used as a prefix for resource names."
  type        = string
  default     = "failover-arcade"
}

variable "env" {
  description = "Environment name. This project uses a single environment."
  type        = string
  default     = "prod"
}

variable "primary_region" {
  description = "Region that hosts the Terraform state bucket and the primary stack."
  type        = string
  default     = "ca-central-1"
}

variable "github_owner" {
  description = "GitHub user or organization that owns the infrastructure repo."
  type        = string
}

variable "github_repo" {
  description = "Name of the infrastructure repo (without the owner)."
  type        = string
}

variable "github_apply_branch" {
  description = "Only workflows running on this branch may assume the apply role."
  type        = string
  default     = "main"
}

variable "budget_limit_usd" {
  description = "Monthly cost budget for the whole account, in USD."
  type        = number
  default     = 30
}

variable "budget_alert_emails" {
  description = "Email addresses that receive budget alerts."
  type        = list(string)

  validation {
    condition     = length(var.budget_alert_emails) > 0
    error_message = "Provide at least one email address for budget alerts."
  }
}
