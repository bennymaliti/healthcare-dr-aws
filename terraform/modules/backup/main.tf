# -----------------------------------------------------------------------------
# AWS Backup Module
# -----------------------------------------------------------------------------

locals {
  vault_name = "${var.project_name}-${var.environment}-backup-vault"
}

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# KMS Key
# -----------------------------------------------------------------------------
resource "aws_kms_key" "backup" {
  description             = "KMS key for AWS Backup - ${var.project_name}-${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Backup Service"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${local.vault_name}-kms"
  })
}

# -----------------------------------------------------------------------------
# Backup Vault
# -----------------------------------------------------------------------------
resource "aws_backup_vault" "main" {
  name        = local.vault_name
  kms_key_arn = aws_kms_key.backup.arn

  tags = merge(var.tags, {
    Name = local.vault_name
  })
}

resource "aws_backup_vault_policy" "main" {
  backup_vault_name = aws_backup_vault.main.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PreventDeletion"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["backup:DeleteRecoveryPoint"]
        Resource  = "*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Role
# -----------------------------------------------------------------------------
resource "aws_iam_role" "backup" {
  name = "${var.project_name}-${var.environment}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# -----------------------------------------------------------------------------
# Backup Plan
# -----------------------------------------------------------------------------
resource "aws_backup_plan" "main" {
  name = "${var.project_name}-${var.environment}-backup-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 3 * * ? *)"
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = var.retention_days
    }

    dynamic "copy_action" {
      for_each = var.enable_cross_region_copy ? [1] : []
      content {
        destination_vault_arn = var.destination_vault_arn
        lifecycle {
          delete_after = var.retention_days
        }
      }
    }

    recovery_point_tags = merge(var.tags, {
      BackupType = "Daily"
    })
  }

  rule {
    rule_name         = "weekly-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 4 ? * SUN *)"
    start_window      = 60
    completion_window = 240

    lifecycle {
      cold_storage_after = 30
      delete_after       = 120
    }

    dynamic "copy_action" {
      for_each = var.enable_cross_region_copy ? [1] : []
      content {
        destination_vault_arn = var.destination_vault_arn
        lifecycle {
          cold_storage_after = 30
          delete_after       = 120
        }
      }
    }

    recovery_point_tags = merge(var.tags, {
      BackupType = "Weekly"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backup-plan"
  })
}

# -----------------------------------------------------------------------------
# Backup Selection
# -----------------------------------------------------------------------------
resource "aws_backup_selection" "main" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.project_name}-${var.environment}-backup-selection"
  plan_id      = aws_backup_plan.main.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }

  resources = var.backup_resource_arns
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "backup_jobs_failed" {
  alarm_name          = "${local.vault_name}-jobs-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfBackupJobsFailed"
  namespace           = "AWS/Backup"
  period              = 86400
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Backup jobs failed in last 24 hours"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    BackupVaultName = aws_backup_vault.main.name
  }

  tags = var.tags
}
