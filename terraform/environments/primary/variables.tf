variable "project_name" {
  description = "Project name"
  type        = string
  default     = "healthcare-dr"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "primary"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "secondary_region" {
  description = "Secondary region"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aurora_engine_version" {
  description = "Aurora MySQL engine version"
  type        = string
  default     = "8.0.mysql_aurora.3.04.0"
}

variable "aurora_instance_class" {
  description = "Aurora instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "aurora_instance_count" {
  description = "Number of Aurora instances"
  type        = number
  default     = 2
}

variable "database_name" {
  description = "Database name"
  type        = string
  default     = "healthcare"
}

variable "database_username" {
  description = "Database master username"
  type        = string
  default     = "admin"
}

variable "database_password" {
  description = "Database master password (leave empty to auto-generate and store in Secrets Manager)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_replication" {
  description = "Enable cross-region replication"
  type        = bool
  default     = true
}

variable "secondary_data_bucket_arn" {
  description = "ARN of secondary data bucket"
  type        = string
  default     = ""
}

variable "secondary_data_bucket_id" {
  description = "ID of secondary data bucket"
  type        = string
  default     = ""
}

variable "secondary_kms_key_arn" {
  description = "ARN of secondary KMS key"
  type        = string
  default     = ""
}

variable "secondary_backup_vault_arn" {
  description = "ARN of secondary backup vault"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email for alerts"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# ECS Configuration
# -----------------------------------------------------------------------------
variable "enable_ecs" {
  description = "Enable ECS containerized application"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

# -----------------------------------------------------------------------------
# WAF Configuration
# -----------------------------------------------------------------------------
variable "enable_waf" {
  description = "Enable AWS WAF"
  type        = bool
  default     = false
}

variable "waf_rate_limit" {
  description = "WAF rate limit per 5 minutes per IP"
  type        = number
  default     = 2000
}

variable "waf_blocked_countries" {
  description = "List of country codes to block"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# GuardDuty Configuration
# -----------------------------------------------------------------------------
variable "enable_guardduty" {
  description = "Enable AWS GuardDuty"
  type        = bool
  default     = true
}

variable "guardduty_auto_remediation" {
  description = "Enable GuardDuty auto-remediation"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Cost Monitoring Configuration
# -----------------------------------------------------------------------------
variable "enable_cost_monitoring" {
  description = "Enable cost monitoring and budgets"
  type        = bool
  default     = true
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
