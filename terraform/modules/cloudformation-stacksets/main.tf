# -----------------------------------------------------------------------------
# CloudFormation StackSets Module - DR Infrastructure Templates
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# IAM Roles for StackSets
# -----------------------------------------------------------------------------
resource "aws_iam_role" "stackset_admin" {
  name = "${var.project_name}-${var.environment}-stackset-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "cloudformation.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "stackset_admin" {
  role       = aws_iam_role.stackset_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"
}

resource "aws_iam_role" "stackset_execution" {
  name = "${var.project_name}-${var.environment}-stackset-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = aws_iam_role.stackset_admin.arn
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "stackset_execution" {
  role       = aws_iam_role.stackset_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------------------------------------
# DR Infrastructure StackSet
# -----------------------------------------------------------------------------
resource "aws_cloudformation_stack_set" "dr_infrastructure" {
  name             = "${var.project_name}-dr-infrastructure"
  description      = "DR infrastructure for healthcare application"
  permission_model = "SELF_MANAGED"

  administration_role_arn = aws_iam_role.stackset_admin.arn
  execution_role_name     = aws_iam_role.stackset_execution.name

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Healthcare DR Infrastructure - Scale-up Resources"

    Parameters = {
      Environment = {
        Type        = "String"
        Default     = "dr"
        Description = "Environment name"
      }
      VPCId = {
        Type        = "AWS::EC2::VPC::Id"
        Description = "VPC ID for DR resources"
      }
      PrivateSubnetIds = {
        Type        = "List<AWS::EC2::Subnet::Id>"
        Description = "Private subnet IDs"
      }
      DesiredCount = {
        Type        = "Number"
        Default     = 2
        Description = "Desired ECS task count"
      }
    }

    Resources = {
      ECSCluster = {
        Type = "AWS::ECS::Cluster"
        Properties = {
          ClusterName = "${var.project_name}-dr-cluster"
          ClusterSettings = [{
            Name  = "containerInsights"
            Value = "enabled"
          }]
          Tags = [{
            Key   = "Name"
            Value = "${var.project_name}-dr-cluster"
          }]
        }
      }

      ECSTaskDefinition = {
        Type = "AWS::ECS::TaskDefinition"
        Properties = {
          Family                   = "${var.project_name}-dr-task"
          NetworkMode              = "awsvpc"
          RequiresCompatibilities  = ["FARGATE"]
          Cpu                      = "256"
          Memory                   = "512"
          ExecutionRoleArn         = { "Fn::GetAtt" = ["ECSExecutionRole", "Arn"] }
          ContainerDefinitions = [{
            Name      = "healthcare-app"
            Image     = "nginx:latest"
            Essential = true
            PortMappings = [{
              ContainerPort = 80
              Protocol      = "tcp"
            }]
            LogConfiguration = {
              LogDriver = "awslogs"
              Options = {
                "awslogs-group"         = "/ecs/${var.project_name}-dr"
                "awslogs-region"        = { Ref = "AWS::Region" }
                "awslogs-stream-prefix" = "ecs"
              }
            }
          }]
        }
      }

      ECSExecutionRole = {
        Type = "AWS::IAM::Role"
        Properties = {
          AssumeRolePolicyDocument = {
            Version = "2012-10-17"
            Statement = [{
              Effect = "Allow"
              Principal = {
                Service = "ecs-tasks.amazonaws.com"
              }
              Action = "sts:AssumeRole"
            }]
          }
          ManagedPolicyArns = [
            "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
          ]
        }
      }

      LogGroup = {
        Type = "AWS::Logs::LogGroup"
        Properties = {
          LogGroupName    = "/ecs/${var.project_name}-dr"
          RetentionInDays = 30
        }
      }
    }

    Outputs = {
      ClusterArn = {
        Description = "ECS Cluster ARN"
        Value       = { "Fn::GetAtt" = ["ECSCluster", "Arn"] }
      }
      TaskDefinitionArn = {
        Description = "Task Definition ARN"
        Value       = { Ref = "ECSTaskDefinition" }
      }
    }
  })

  lifecycle {
    ignore_changes = [administration_role_arn]
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# StackSet Instance (Deploy to DR Region)
# -----------------------------------------------------------------------------
resource "aws_cloudformation_stack_set_instance" "dr_region" {
  count = var.deploy_to_dr_region ? 1 : 0

  stack_set_name = aws_cloudformation_stack_set.dr_infrastructure.name
  region         = var.dr_region
  account_id     = data.aws_caller_identity.current.account_id

  parameter_overrides = {
    Environment      = var.environment
    VPCId            = var.dr_vpc_id
    PrivateSubnetIds = join(",", var.dr_private_subnet_ids)
    DesiredCount     = var.dr_desired_count
  }
}
