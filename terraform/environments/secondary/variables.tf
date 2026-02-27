variable "project_name" {
  description = "Project name"
  type        = string
  default     = "healthcare-dr"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "secondary"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "primary_region" {
  description = "Primary region"
  type        = string
  default     = "eu-west-2"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.1.0.0/16"
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

variable "primary_rds_cluster_arn" {
  description = "ARN of primary Aurora cluster"
  type        = string
}

variable "deletion_protection" {
  description = "Enable deletion protection for RDS"
  type        = bool
  default     = true
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
  description = "Enable ECS containerized application (standby)"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}

variable "primary_db_secret_arn" {
  description = "Primary region DB secret ARN"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# GuardDuty Configuration
# -----------------------------------------------------------------------------
variable "enable_guardduty" {
  description = "Enable AWS GuardDuty"
  type        = bool
  default     = true
}
