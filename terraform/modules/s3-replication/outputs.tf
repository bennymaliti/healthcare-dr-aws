output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.s3.arn
}

output "kms_key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.s3.key_id
}
