# -----------------------------------------------------------------------------
# Healthcare DR - Secondary Region (eu-west-1 Ireland) - STANDBY
# -----------------------------------------------------------------------------

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Region      = var.aws_region
    Role        = "DR-Standby"
  }
}

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# VPC (Single NAT for cost savings)
# -----------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_flow_logs     = true
  enable_vpc_endpoints = true

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# S3 Bucket (Replication Destination)
# -----------------------------------------------------------------------------
module "healthcare_data_bucket" {
  source = "../../modules/s3-replication"

  project_name       = var.project_name
  environment        = var.environment
  bucket_purpose     = "healthcare-data"
  enable_replication = false

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
# RDS Aurora (Cross-Region Read Replica)
# -----------------------------------------------------------------------------
module "rds" {
  source = "../../modules/rds"

  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  vpc_cidr             = var.vpc_cidr
  db_subnet_group_name = module.vpc.db_subnet_group_name
  is_primary_region    = false
  source_cluster_arn   = var.primary_rds_cluster_arn
  source_region        = var.primary_region
  engine_version       = var.aurora_engine_version
  instance_class       = var.aurora_instance_class
  instance_count       = 1
  deletion_protection  = true
  skip_final_snapshot  = true
  alarm_sns_topic_arn  = aws_sns_topic.alerts.arn

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# AWS Backup Vault (Receives copies from primary)
# -----------------------------------------------------------------------------
module "backup" {
  source = "../../modules/backup"

  project_name             = var.project_name
  environment              = var.environment
  retention_days           = 35
  enable_cross_region_copy = false
  alarm_sns_topic_arn      = aws_sns_topic.alerts.arn
  backup_resource_arns     = []

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
# CloudWatch Dashboard
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "dr_status" {
  dashboard_name = "${var.project_name}-${var.environment}-dr-status"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# Healthcare DR - Secondary Region (${var.aws_region}) - STANDBY\n⚠️ Execute failover runbook if primary region fails"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          title   = "Aurora Replica Lag (ms)"
          metrics = [["AWS/RDS", "AuroraReplicaLag", "DBClusterIdentifier", module.rds.cluster_id]]
          period  = 300
          stat    = "Average"
          region  = var.aws_region
          annotations = {
            horizontal = [{
              label = "RPO Threshold (5 min)"
              value = 300000
              color = "#ff0000"
            }]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          title   = "Aurora CPU (Standby)"
          metrics = [["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", module.rds.cluster_id]]
          period  = 300
          stat    = "Average"
          region  = var.aws_region
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# ECS - Containerized Application (Standby - Scaled Down)
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
  db_secret_arn       = var.primary_db_secret_arn
  data_bucket_arn     = module.healthcare_data_bucket.bucket_arn
  certificate_arn     = var.certificate_arn
  desired_count       = 0 # Scaled down for DR standby
  min_capacity        = 0
  max_capacity        = 10
  deletion_protection = false # Allow deletion in DR region

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# GuardDuty - Threat Detection (Both regions should have GuardDuty)
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
