# -----------------------------------------------------------------------------
# AWS GuardDuty Module - Threat Detection
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# -----------------------------------------------------------------------------
# GuardDuty Detector
# -----------------------------------------------------------------------------
resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = var.finding_frequency

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = var.enable_kubernetes_protection
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = var.enable_malware_protection
        }
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-guardduty"
  })
}

# -----------------------------------------------------------------------------
# GuardDuty Filter for High Severity
# -----------------------------------------------------------------------------
resource "aws_guardduty_filter" "high_severity" {
  name        = "${local.name_prefix}-high-severity"
  action      = "ARCHIVE"
  detector_id = aws_guardduty_detector.main.id
  rank        = 1

  finding_criteria {
    criterion {
      field  = "severity"
      equals = ["8", "9"]
    }
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# SNS Topic for Findings
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "guardduty_findings" {
  name = "${local.name_prefix}-guardduty-findings"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "guardduty_email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.guardduty_findings.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# -----------------------------------------------------------------------------
# EventBridge Rule for GuardDuty Findings
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${local.name_prefix}-guardduty-findings"
  description = "Capture GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", var.minimum_severity] }]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.guardduty_findings.arn

  input_transformer {
    input_paths = {
      severity    = "$.detail.severity"
      type        = "$.detail.type"
      title       = "$.detail.title"
      description = "$.detail.description"
      region      = "$.region"
      account     = "$.account"
    }
    input_template = <<EOF
{
  "alert": "GuardDuty Finding",
  "severity": <severity>,
  "type": "<type>",
  "title": "<title>",
  "description": "<description>",
  "region": "<region>",
  "account": "<account>"
}
EOF
  }
}

resource "aws_sns_topic_policy" "guardduty_findings" {
  arn = aws_sns_topic.guardduty_findings.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridge"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.guardduty_findings.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Lambda for Auto-Remediation (Optional)
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "remediation" {
  count         = var.enable_auto_remediation ? 1 : 0
  function_name = "${local.name_prefix}-guardduty-remediation"
  role          = aws_iam_role.remediation[0].arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60

  filename         = data.archive_file.remediation[0].output_path
  source_code_hash = data.archive_file.remediation[0].output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.guardduty_findings.arn
    }
  }

  tags = var.tags
}

data "archive_file" "remediation" {
  count       = var.enable_auto_remediation ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/remediation.zip"

  source {
    content  = <<-EOF
import json
import boto3
import os

def handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    
    finding = event.get('detail', {})
    severity = finding.get('severity', 0)
    finding_type = finding.get('type', '')
    
    # Example: Block compromised IAM credentials
    if 'UnauthorizedAccess:IAMUser' in finding_type:
        # Add remediation logic here
        print(f"High severity IAM finding detected: {finding_type}")
    
    # Example: Isolate compromised EC2 instance
    if 'UnauthorizedAccess:EC2' in finding_type and severity >= 7:
        # Add remediation logic here
        print(f"High severity EC2 finding detected: {finding_type}")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Processed')
    }
EOF
    filename = "index.py"
  }
}

resource "aws_iam_role" "remediation" {
  count = var.enable_auto_remediation ? 1 : 0
  name  = "${local.name_prefix}-guardduty-remediation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "remediation" {
  count = var.enable_auto_remediation ? 1 : 0
  name  = "${local.name_prefix}-guardduty-remediation-policy"
  role  = aws_iam_role.remediation[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:ModifyInstanceAttribute",
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.guardduty_findings.arn
      }
    ]
  })
}

resource "aws_lambda_permission" "eventbridge" {
  count         = var.enable_auto_remediation ? 1 : 0
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediation[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_findings.arn
}

resource "aws_cloudwatch_event_target" "remediation_lambda" {
  count     = var.enable_auto_remediation ? 1 : 0
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "invoke-remediation-lambda"
  arn       = aws_lambda_function.remediation[0].arn
}

# -----------------------------------------------------------------------------
# CloudWatch Metrics
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "high_severity_findings" {
  alarm_name          = "${local.name_prefix}-guardduty-high-severity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HighSeverityFindings"
  namespace           = "GuardDuty/${local.name_prefix}"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "High severity GuardDuty findings detected"
  alarm_actions       = [aws_sns_topic.guardduty_findings.arn]

  tags = var.tags
}
