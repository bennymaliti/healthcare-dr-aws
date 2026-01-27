output "detector_id" {
  description = "GuardDuty detector ID"
  value       = aws_guardduty_detector.main.id
}

output "detector_arn" {
  description = "GuardDuty detector ARN"
  value       = aws_guardduty_detector.main.arn
}

output "sns_topic_arn" {
  description = "SNS topic ARN for findings"
  value       = aws_sns_topic.guardduty_findings.arn
}

output "event_rule_arn" {
  description = "EventBridge rule ARN"
  value       = aws_cloudwatch_event_rule.guardduty_findings.arn
}

output "remediation_lambda_arn" {
  description = "Remediation Lambda ARN (if enabled)"
  value       = var.enable_auto_remediation ? aws_lambda_function.remediation[0].arn : null
}
