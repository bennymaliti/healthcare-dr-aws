variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "bucket_purpose" {
  description = "Purpose of the bucket (data, backups, logs)"
  type        = string
}

variable "enable_replication" {
  description = "Enable cross-region replication"
  type        = bool
  default     = false
}

variable "destination_bucket_arn" {
  description = "ARN of destination bucket"
  type        = string
  default     = ""
}

variable "destination_bucket_id" {
  description = "ID of destination bucket"
  type        = string
  default     = ""
}

variable "destination_kms_key_arn" {
  description = "ARN of KMS key in destination region"
  type        = string
  default     = ""
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
