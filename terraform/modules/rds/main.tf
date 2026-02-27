# -----------------------------------------------------------------------------
# RDS Aurora MySQL Module - Cross-Region Replication
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Random Password for Master User
# -----------------------------------------------------------------------------
resource "random_password" "master" {
  count   = var.source_cluster_arn == "" ? 1 : 0
  length  = 16
  special = false
}
locals {
  is_primary         = var.is_primary_region
  cluster_identifier = "${var.project_name}-${var.environment}-aurora"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Secrets Manager for Database Credentials
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "db_credentials" {
  count = local.is_primary ? 1 : 0
  name  = "${var.project_name}-${var.environment}-db-credentials"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-db-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  count     = local.is_primary ? 1 : 0
  secret_id = aws_secretsmanager_secret.db_credentials[0].id

  secret_string = jsonencode({
    username = var.master_username
    password = var.master_password != "" ? var.master_password : random_password.db_password[0].result
    database = var.database_name
  })
}

resource "random_password" "db_password" {
  count            = local.is_primary && var.master_password == "" ? 1 : 0
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# -----------------------------------------------------------------------------
# KMS Key for Database Encryption
# -----------------------------------------------------------------------------
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption - ${var.project_name}-${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  multi_region            = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rds-kms"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-${var.environment}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-${var.environment}-aurora-sg"
  description = "Security group for Aurora cluster"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from application"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  ingress {
    description = "MySQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-sg"
  })
}

# -----------------------------------------------------------------------------
# Parameter Groups
# -----------------------------------------------------------------------------
resource "aws_rds_cluster_parameter_group" "aurora" {
  family      = "aurora-mysql8.0"
  name        = "${var.project_name}-${var.environment}-cluster-params"
  description = "Aurora cluster parameter group"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name         = "binlog_format"
    value        = "MIXED"
    apply_method = "pending-reboot"
  }

  tags = var.tags
}

resource "aws_db_parameter_group" "aurora" {
  family      = "aurora-mysql8.0"
  name        = "${var.project_name}-${var.environment}-db-params"
  description = "Aurora DB parameter group"

  parameter {
    name  = "max_connections"
    value = "1000"
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Aurora Cluster (Primary)
# -----------------------------------------------------------------------------
resource "aws_rds_cluster" "primary" {
  count = local.is_primary ? 1 : 0

  cluster_identifier = local.cluster_identifier
  engine             = "aurora-mysql"
  engine_version     = var.engine_version
  engine_mode        = "provisioned"

  database_name   = var.database_name
  master_username = var.master_username
  master_password = var.master_password != "" ? var.master_password : random_password.db_password[0].result

  db_subnet_group_name            = var.db_subnet_group_name
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name

  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  enabled_cloudwatch_logs_exports = ["audit", "error", "slowquery"]

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.cluster_identifier}-final"

  tags = merge(var.tags, {
    Name = local.cluster_identifier
  })
}

# -----------------------------------------------------------------------------
# Aurora Instances (Primary)
# -----------------------------------------------------------------------------
resource "aws_rds_cluster_instance" "primary" {
  count = local.is_primary ? var.instance_count : 0

  identifier         = "${local.cluster_identifier}-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.primary[0].id

  engine         = "aurora-mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_subnet_group_name    = var.db_subnet_group_name
  db_parameter_group_name = aws_db_parameter_group.aurora.name

  publicly_accessible          = false
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled = false

  auto_minor_version_upgrade = true

  tags = merge(var.tags, {
    Name = "${local.cluster_identifier}-${count.index + 1}"
  })
}

# -----------------------------------------------------------------------------
# Aurora Cluster (Secondary - Read Replica)
# -----------------------------------------------------------------------------
resource "aws_rds_cluster" "secondary" {
  count = local.is_primary ? 0 : 1

  cluster_identifier = local.cluster_identifier
  engine             = "aurora-mysql"
  engine_version     = var.engine_version
  engine_mode        = "provisioned"

  # Only set replication if source exists
  replication_source_identifier = var.source_cluster_arn != "" ? var.source_cluster_arn : null
  source_region                 = var.source_cluster_arn != "" ? var.source_region : null

  # Required when NOT a replica (standalone cluster)
  database_name   = var.source_cluster_arn == "" ? var.database_name : null
  master_username = var.source_cluster_arn == "" ? var.master_username : null
  master_password = var.source_cluster_arn == "" ? random_password.master[0].result : null

  db_subnet_group_name            = var.db_subnet_group_name
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name

  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  enabled_cloudwatch_logs_exports = ["audit", "error", "slowquery"]
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = true

  depends_on = [aws_kms_key.rds]

  tags = merge(var.tags, {
    Name = local.cluster_identifier
    Role = var.source_cluster_arn != "" ? "CrossRegionReplica" : "StandaloneSecondary"
  })
}

# -----------------------------------------------------------------------------
# Aurora Instances (Secondary)
# -----------------------------------------------------------------------------
resource "aws_rds_cluster_instance" "secondary" {
  count = local.is_primary ? 0 : var.instance_count

  identifier         = "${local.cluster_identifier}-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.secondary[0].id

  engine         = "aurora-mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_subnet_group_name    = var.db_subnet_group_name
  db_parameter_group_name = aws_db_parameter_group.aurora.name

  publicly_accessible          = false
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled = false

  auto_minor_version_upgrade = true

  tags = merge(var.tags, {
    Name = "${local.cluster_identifier}-${count.index + 1}"
    Role = "CrossRegionReplica"
  })
}

# -----------------------------------------------------------------------------
# Enhanced Monitoring IAM Role
# -----------------------------------------------------------------------------
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  alarm_name          = "${local.cluster_identifier}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Aurora cluster CPU utilization is high"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    DBClusterIdentifier = local.is_primary ? aws_rds_cluster.primary[0].cluster_identifier : aws_rds_cluster.secondary[0].cluster_identifier
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "replica_lag" {
  count = local.is_primary ? 0 : 1

  alarm_name          = "${local.cluster_identifier}-replica-lag"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "AuroraReplicaLag"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 300000
  alarm_description   = "Aurora cross-region replica lag exceeds 5 minutes"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.secondary[0].cluster_identifier
  }

  tags = var.tags
}
