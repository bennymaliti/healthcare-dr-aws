variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 35
}

variable "enable_cross_region_copy" {
  description = "Enable cross-region backup copy"
  type        = bool
  default     = false
}

variable "destination_vault_arn" {
  description = "ARN of destination vault for cross-region copy"
  type        = string
  default     = ""
}

variable "backup_resource_arns" {
  description = "List of resource ARNs to backup"
  type        = list(string)
  default     = []
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
