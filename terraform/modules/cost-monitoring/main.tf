# -----------------------------------------------------------------------------
# Cost Monitoring Module - Budget Alerts and Dashboard
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# -----------------------------------------------------------------------------
# SNS Topic for Cost Alerts
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "cost_alerts" {
  name = "${local.name_prefix}-cost-alerts"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "cost_alerts_email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_sns_topic_policy" "cost_alerts" {
  arn = aws_sns_topic.cost_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBudgetsPublish"
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.cost_alerts.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# AWS Budget - Monthly Total
# -----------------------------------------------------------------------------
resource "aws_budgets_budget" "monthly_total" {
  name              = "${local.name_prefix}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Project$${var.project_name}"]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 50
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [time_period_start]
  }
}

# -----------------------------------------------------------------------------
# AWS Budget - RDS
# -----------------------------------------------------------------------------
resource "aws_budgets_budget" "rds" {
  name              = "${local.name_prefix}-rds-budget"
  budget_type       = "COST"
  limit_amount      = var.rds_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  cost_filter {
    name   = "Service"
    values = ["Amazon Relational Database Service"]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [time_period_start]
  }
}

# -----------------------------------------------------------------------------
# AWS Budget - EC2/ECS
# -----------------------------------------------------------------------------
resource "aws_budgets_budget" "compute" {
  name              = "${local.name_prefix}-compute-budget"
  budget_type       = "COST"
  limit_amount      = var.compute_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  cost_filter {
    name   = "Service"
    values = ["Amazon Elastic Compute Cloud - Compute", "Amazon Elastic Container Service"]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [time_period_start]
  }
}

# -----------------------------------------------------------------------------
# AWS Budget - Data Transfer
# -----------------------------------------------------------------------------
resource "aws_budgets_budget" "data_transfer" {
  name              = "${local.name_prefix}-data-transfer-budget"
  budget_type       = "COST"
  limit_amount      = var.data_transfer_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  cost_filter {
    name   = "Service"
    values = ["AWS Data Transfer"]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [time_period_start]
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboard - Cost Overview
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "cost_monitoring" {
  dashboard_name = "${local.name_prefix}-cost-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# 💰 Cost Monitoring Dashboard - ${var.project_name}"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 12
        height = 6
        properties = {
          title  = "Estimated Monthly Charges"
          region = "us-east-1"
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD", { stat = "Maximum", period = 86400 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 1
        width  = 12
        height = 6
        properties = {
          title  = "RDS Costs"
          region = "us-east-1"
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD", "ServiceName", "Amazon Relational Database Service", { stat = "Maximum", period = 86400 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 8
        height = 6
        properties = {
          title  = "EC2 Costs"
          region = "us-east-1"
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD", "ServiceName", "Amazon Elastic Compute Cloud - Compute", { stat = "Maximum", period = 86400 }]
          ]
          view = "singleValue"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 7
        width  = 8
        height = 6
        properties = {
          title  = "S3 Costs"
          region = "us-east-1"
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD", "ServiceName", "Amazon Simple Storage Service", { stat = "Maximum", period = 86400 }]
          ]
          view = "singleValue"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 7
        width  = 8
        height = 6
        properties = {
          title  = "Data Transfer Costs"
          region = "us-east-1"
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD", "ServiceName", "AWS Data Transfer", { stat = "Maximum", period = 86400 }]
          ]
          view = "singleValue"
        }
      },
      {
        type   = "text"
        x      = 0
        y      = 13
        width  = 24
        height = 2
        properties = {
          markdown = <<-EOF
## Budget Status
| Budget | Limit | Alert Thresholds |
|--------|-------|------------------|
| Monthly Total | $${var.monthly_budget_limit} | 50%, 80%, 100% |
| RDS | $${var.rds_budget_limit} | 80% |
| Compute | $${var.compute_budget_limit} | 80% |
| Data Transfer | $${var.data_transfer_budget_limit} | 80% |
EOF
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Cost Anomaly Detection
# -----------------------------------------------------------------------------
# resource "aws_ce_anomaly_monitor" "main" {
#  count = 0 # Disable for now - can be enabled if needed
#  name              = "${local.name_prefix}-anomaly-monitor"
#  monitor_type      = "DIMENSIONAL"
#  monitor_dimension = "SERVICE"
#
#  tags = var.tags
#}
#
# resource "aws_ce_anomaly_subscription" "main" {
#  name      = "${local.name_prefix}-anomaly-subscription"
#  frequency = "DAILY"
#
#  monitor_arn_list = [aws_ce_anomaly_monitor.main.arn]
#
#  subscriber {
#    type    = "SNS"
#    address = aws_sns_topic.cost_alerts.arn
#  }
#
#  threshold_expression {
#    dimension {
#      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
#      values        = [var.anomaly_threshold]
#      match_options = ["GREATER_THAN_OR_EQUAL"]
#    }
#  }
#
#  tags = var.tags
#}
