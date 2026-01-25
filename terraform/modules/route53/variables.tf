variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/health"
}

variable "primary_alb_dns_name" {
  description = "DNS name of primary ALB"
  type        = string
}

variable "primary_alb_zone_id" {
  description = "Zone ID of primary ALB"
  type        = string
}

variable "secondary_alb_dns_name" {
  description = "DNS name of secondary ALB"
  type        = string
}

variable "secondary_alb_zone_id" {
  description = "Zone ID of secondary ALB"
  type        = string
}

variable "create_sns_topic" {
  description = "Create SNS topic for notifications"
  type        = bool
  default     = true
}

variable "notification_email" {
  description = "Email for failover notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
