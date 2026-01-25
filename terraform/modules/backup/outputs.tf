output "vault_id" {
  description = "ID of the backup vault"
  value       = aws_backup_vault.main.id
}

output "vault_arn" {
  description = "ARN of the backup vault"
  value       = aws_backup_vault.main.arn
}

output "vault_name" {
  description = "Name of the backup vault"
  value       = aws_backup_vault.main.name
}

output "plan_id" {
  description = "ID of the backup plan"
  value       = aws_backup_plan.main.id
}

output "plan_arn" {
  description = "ARN of the backup plan"
  value       = aws_backup_plan.main.arn
}

output "iam_role_arn" {
  description = "ARN of the backup IAM role"
  value       = aws_iam_role.backup.arn
}

output "kms_key_arn" {
  description = "ARN of the backup vault KMS key"
  value       = aws_kms_key.backup.arn
}
