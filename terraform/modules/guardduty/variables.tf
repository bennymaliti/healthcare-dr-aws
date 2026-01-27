variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "finding_frequency" {
  description = "Finding publishing frequency"
  type        = string
  default     = "FIFTEEN_MINUTES"
  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.finding_frequency)
    error_message = "Valid values: FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS"
  }
}

variable "enable_kubernetes_protection" {
  description = "Enable Kubernetes audit log monitoring"
  type        = bool
  default     = false
}

variable "enable_malware_protection" {
  description = "Enable malware protection for EBS"
  type        = bool
  default     = true
}

variable "minimum_severity" {
  description = "Minimum severity for event notifications (1-10)"
  type        = number
  default     = 4
}

variable "notification_email" {
  description = "Email for GuardDuty findings"
  type        = string
  default     = ""
}

variable "enable_auto_remediation" {
  description = "Enable auto-remediation Lambda"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
