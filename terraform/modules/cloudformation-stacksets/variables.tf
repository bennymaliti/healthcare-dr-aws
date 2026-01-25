variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "deploy_to_dr_region" {
  description = "Deploy StackSet instance to DR region"
  type        = bool
  default     = false
}

variable "dr_region" {
  description = "DR region for StackSet deployment"
  type        = string
  default     = "eu-west-1"
}

variable "dr_vpc_id" {
  description = "VPC ID in DR region"
  type        = string
  default     = ""
}

variable "dr_private_subnet_ids" {
  description = "Private subnet IDs in DR region"
  type        = list(string)
  default     = []
}

variable "dr_desired_count" {
  description = "Desired ECS task count in DR"
  type        = number
  default     = 0
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
