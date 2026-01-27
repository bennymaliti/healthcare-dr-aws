variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = string
  default     = "500"
}

variable "rds_budget_limit" {
  description = "RDS monthly budget limit in USD"
  type        = string
  default     = "200"
}

variable "compute_budget_limit" {
  description = "Compute monthly budget limit in USD"
  type        = string
  default     = "100"
}

variable "data_transfer_budget_limit" {
  description = "Data transfer monthly budget limit in USD"
  type        = string
  default     = "50"
}

variable "anomaly_threshold" {
  description = "Cost anomaly threshold in USD"
  type        = string
  default     = "50"
}

variable "notification_email" {
  description = "Email for cost alerts"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
