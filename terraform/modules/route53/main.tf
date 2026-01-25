# -----------------------------------------------------------------------------
# Route 53 DNS Failover Module
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Health Check - Primary
# -----------------------------------------------------------------------------
resource "aws_route53_health_check" "primary" {
  fqdn              = var.primary_alb_dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = var.health_check_path
  failure_threshold = 3
  request_interval  = 30

  regions = ["us-east-1", "eu-west-1", "ap-southeast-1"]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-primary-health-check"
  })
}

# -----------------------------------------------------------------------------
# Health Check - Secondary
# -----------------------------------------------------------------------------
resource "aws_route53_health_check" "secondary" {
  fqdn              = var.secondary_alb_dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = var.health_check_path
  failure_threshold = 3
  request_interval  = 30

  regions = ["us-east-1", "eu-west-1", "ap-southeast-1"]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-secondary-health-check"
  })
}

# -----------------------------------------------------------------------------
# DNS Records - Failover Policy
# -----------------------------------------------------------------------------
resource "aws_route53_record" "primary" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary.id

  alias {
    name                   = var.primary_alb_dns_name
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "secondary" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier  = "secondary"
  health_check_id = aws_route53_health_check.secondary.id

  alias {
    name                   = var.secondary_alb_dns_name
    zone_id                = var.secondary_alb_zone_id
    evaluate_target_health = true
  }
}

# -----------------------------------------------------------------------------
# SNS Topic for Notifications
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "failover" {
  count = var.create_sns_topic ? 1 : 0
  name  = "${var.project_name}-${var.environment}-failover-notifications"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "failover_email" {
  count     = var.create_sns_topic && var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.failover[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# -----------------------------------------------------------------------------
# EventBridge Rule for Failover Events
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "failover" {
  name        = "${var.project_name}-${var.environment}-failover-events"
  description = "Capture Route 53 health check status changes"

  event_pattern = jsonencode({
    source      = ["aws.route53"]
    detail-type = ["Route 53 Health Check Status Changed"]
    detail = {
      HealthCheckId = [
        aws_route53_health_check.primary.id,
        aws_route53_health_check.secondary.id
      ]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "failover_sns" {
  count     = var.create_sns_topic ? 1 : 0
  rule      = aws_cloudwatch_event_rule.failover.name
  target_id = "failover-notification"
  arn       = aws_sns_topic.failover[0].arn
}

# -----------------------------------------------------------------------------
# CloudWatch Alarm
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "primary_health" {
  alarm_name          = "${var.project_name}-${var.environment}-primary-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Primary region health check failed"
  alarm_actions       = var.create_sns_topic ? [aws_sns_topic.failover[0].arn] : []
  ok_actions          = var.create_sns_topic ? [aws_sns_topic.failover[0].arn] : []

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary.id
  }

  tags = var.tags
}
