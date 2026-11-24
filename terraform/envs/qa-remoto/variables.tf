variable "aws_region" {
  description = "AWS region for the remote QA environment."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name."
  type        = string
  default     = "spa-unas"
}

variable "monthly_budget_usd" {
  description = "Monthly AWS budget in USD."
  type        = number
  default     = 10

  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "The monthly budget must be greater than zero."
  }
}

variable "budget_alert_email" {
  description = "Email address for AWS budget notifications."
  type        = string
}

variable "build_timeout_minutes" {
  description = "Maximum CodeBuild execution time in minutes."
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days."
  type        = number
  default     = 7
}
