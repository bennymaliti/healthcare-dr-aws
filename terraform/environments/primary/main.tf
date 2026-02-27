# -----------------------------------------------------------------------------
# Healthcare DR - Primary Region (eu-west-2 London)
# -----------------------------------------------------------------------------

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Region      = var.aws_region
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_flow_logs     = true
  enable_vpc_endpoints = true

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# S3 Buckets
# -----------------------------------------------------------------------------
module "healthcare_data_bucket" {
  source = "../../modules/s3-replication"

  project_name   = var.project_name
  environment    = var.environment
  bucket_purpose = "healthcare-data"

  enable_replication      = var.enable_replication
  destination_bucket_arn  = var.secondary_data_bucket_arn
  destination_bucket_id   = var.secondary_data_bucket_id
  destination_kms_key_arn = var.secondary_kms_key_arn
  alarm_sns_topic_arn     = aws_sns_topic.alerts.arn

  tags = local.common_tags
}

module "logs_bucket" {
  source = "../../modules/s3-replication"

  project_name       = var.project_name
  environment        = var.environment
  bucket_purpose     = "logs"
  enable_replication = false

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# RDS Aurora
# -----------------------------------------------------------------------------
module "rds" {
  source = "../../modules/rds"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  vpc_cidr                = var.vpc_cidr
  db_subnet_group_name    = module.vpc.db_subnet_group_name
  is_primary_region       = true
  engine_version          = var.aurora_engine_version
  instance_class          = var.aurora_instance_class
  instance_count          = var.aurora_instance_count
  database_name           = var.database_name
  master_username         = var.database_username
  master_password         = var.database_password
  backup_retention_period = 35
  deletion_protection     = true
  skip_final_snapshot     = false
  alarm_sns_topic_arn     = aws_sns_topic.alerts.arn

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# AWS Backup
# -----------------------------------------------------------------------------
module "backup" {
  source = "../../modules/backup"

  project_name             = var.project_name
  environment              = var.environment
  retention_days           = 35
  enable_cross_region_copy = var.enable_replication
  destination_vault_arn    = var.secondary_backup_vault_arn
  alarm_sns_topic_arn      = aws_sns_topic.alerts.arn

  backup_resource_arns = [
    module.rds.cluster_arn
  ]

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# SNS Topic
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# -----------------------------------------------------------------------------
# ECS - Containerized Application
# -----------------------------------------------------------------------------
module "ecs" {
  count  = var.enable_ecs ? 1 : 0
  source = "../../modules/ecs"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  vpc_cidr_block      = var.vpc_cidr
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  image_tag           = "latest"
  kms_key_arn         = module.rds.kms_key_arn
  db_host             = module.rds.cluster_endpoint
  db_secret_arn       = module.rds.secrets_manager_arn
  data_bucket_arn     = module.healthcare_data_bucket.bucket_arn
  certificate_arn     = var.certificate_arn
  desired_count       = 2
  min_capacity        = 2
  max_capacity        = 10
  deletion_protection = true

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# WAF - Web Application Firewall
# -----------------------------------------------------------------------------
module "waf" {
  count  = var.enable_waf ? 1 : 0
  source = "../../modules/waf"

  project_name = var.project_name
  environment  = var.environment
  alb_arn      = var.enable_ecs ? module.ecs[0].alb_arn : ""

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# GuardDuty - Threat Detection
# -----------------------------------------------------------------------------
module "guardduty" {
  count  = var.enable_guardduty ? 1 : 0
  source = "../../modules/guardduty"

  project_name              = var.project_name
  environment               = var.environment
  notification_email        = var.alert_email
  enable_malware_protection = true
  enable_auto_remediation   = false

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Cost Monitoring
# -----------------------------------------------------------------------------
module "cost_monitoring" {
  count  = var.enable_cost_monitoring ? 1 : 0
  source = "../../modules/cost-monitoring"

  project_name         = var.project_name
  environment          = var.environment
  monthly_budget_limit = var.monthly_budget_limit

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboard
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# Healthcare DR - Primary Region (${var.aws_region})"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          title   = "Aurora CPU"
          metrics = [["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", module.rds.cluster_id]]
          period  = 300
          stat    = "Average"
          region  = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          title   = "Aurora Connections"
          metrics = [["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", module.rds.cluster_id]]
          period  = 300
          stat    = "Average"
          region  = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          title   = "Backup Jobs"
          metrics = [
            ["AWS/Backup", "NumberOfBackupJobsCompleted", "BackupVaultName", module.backup.vault_name],
            [".", "NumberOfBackupJobsFailed", ".", "."]
          ]
          period = 86400
          stat   = "Sum"
          region = var.aws_region
        }
      }
    ]
  })
}
