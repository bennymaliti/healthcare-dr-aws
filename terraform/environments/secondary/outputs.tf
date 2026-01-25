output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "Database subnet IDs"
  value       = module.vpc.database_subnet_ids
}

output "rds_cluster_arn" {
  description = "Aurora cluster ARN"
  value       = module.rds.cluster_arn
}

output "rds_cluster_endpoint" {
  description = "Aurora cluster endpoint (read-only until promoted)"
  value       = module.rds.cluster_endpoint
}

output "data_bucket_arn" {
  description = "Healthcare data bucket ARN"
  value       = module.healthcare_data_bucket.bucket_arn
}

output "data_bucket_id" {
  description = "Healthcare data bucket ID"
  value       = module.healthcare_data_bucket.bucket_id
}

output "kms_key_arn" {
  description = "S3 KMS key ARN"
  value       = module.healthcare_data_bucket.kms_key_arn
}

output "backup_vault_arn" {
  description = "Backup vault ARN"
  value       = module.backup.vault_arn
}

output "sns_topic_arn" {
  description = "Alerts SNS topic ARN"
  value       = aws_sns_topic.alerts.arn
}
