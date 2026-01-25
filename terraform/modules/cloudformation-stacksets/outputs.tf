output "stack_set_name" {
  description = "Name of the CloudFormation StackSet"
  value       = aws_cloudformation_stack_set.dr_infrastructure.name
}

output "stack_set_id" {
  description = "ID of the CloudFormation StackSet"
  value       = aws_cloudformation_stack_set.dr_infrastructure.id
}

output "admin_role_arn" {
  description = "ARN of the StackSet admin role"
  value       = aws_iam_role.stackset_admin.arn
}

output "execution_role_arn" {
  description = "ARN of the StackSet execution role"
  value       = aws_iam_role.stackset_execution.arn
}
