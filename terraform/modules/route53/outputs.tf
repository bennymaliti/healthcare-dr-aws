output "primary_health_check_id" {
  description = "ID of the primary health check"
  value       = aws_route53_health_check.primary.id
}

output "secondary_health_check_id" {
  description = "ID of the secondary health check"
  value       = aws_route53_health_check.secondary.id
}

output "primary_record_fqdn" {
  description = "FQDN of the primary DNS record"
  value       = aws_route53_record.primary.fqdn
}

output "failover_sns_topic_arn" {
  description = "ARN of the failover SNS topic"
  value       = var.create_sns_topic ? aws_sns_topic.failover[0].arn : null
}
