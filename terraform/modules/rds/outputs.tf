output "cluster_id" {
  description = "ID of the Aurora cluster"
  value       = var.is_primary_region ? aws_rds_cluster.primary[0].id : aws_rds_cluster.secondary[0].id
}

output "cluster_arn" {
  description = "ARN of the Aurora cluster"
  value       = var.is_primary_region ? aws_rds_cluster.primary[0].arn : aws_rds_cluster.secondary[0].arn
}

output "cluster_endpoint" {
  description = "Writer endpoint"
  value       = var.is_primary_region ? aws_rds_cluster.primary[0].endpoint : aws_rds_cluster.secondary[0].endpoint
}

output "cluster_reader_endpoint" {
  description = "Reader endpoint"
  value       = var.is_primary_region ? aws_rds_cluster.primary[0].reader_endpoint : aws_rds_cluster.secondary[0].reader_endpoint
}

output "cluster_port" {
  description = "Port"
  value       = var.is_primary_region ? aws_rds_cluster.primary[0].port : aws_rds_cluster.secondary[0].port
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.aurora.id
}

output "kms_key_arn" {
  description = "KMS key ARN"
  value       = aws_kms_key.rds.arn
}

output "secrets_manager_arn" {
  description = "Secrets Manager secret ARN for database credentials"
  value       = var.is_primary_region ? aws_secretsmanager_secret.db_credentials[0].arn : null
}

output "secrets_manager_name" {
  description = "Secrets Manager secret name"
  value       = var.is_primary_region ? aws_secretsmanager_secret.db_credentials[0].name : null
}
