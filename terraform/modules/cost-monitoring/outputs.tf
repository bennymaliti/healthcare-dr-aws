output "sns_topic_arn" {
  description = "SNS topic ARN for cost alerts"
  value       = aws_sns_topic.cost_alerts.arn
}

output "monthly_budget_id" {
  description = "Monthly budget ID"
  value       = aws_budgets_budget.monthly_total.id
}

output "dashboard_arn" {
  description = "Cost dashboard ARN"
  value       = aws_cloudwatch_dashboard.cost_monitoring.dashboard_arn
}

output "anomaly_monitor_arn" {
  description = "Cost anomaly monitor ARN"
  value       = null # Disabled - AWS limit reached. Can be enabled if needed: aws_ce_anomaly_monitor.main.arn
}
