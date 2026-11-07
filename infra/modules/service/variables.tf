variable "name" {
  description = "Base name used for resource tagging and naming (e.g., claimtrack-dev)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB and ECS tasks will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB and ECS tasks"
  type        = list(string)
}

variable "image_tag" {
  description = "Docker container image tag to deploy (e.g., v1 or latest)"
  type        = string
}

variable "container_port" {
  description = "Port exposed by the FastAPI container"
  type        = number
  default     = 8000
}

variable "db_host" {
  description = "Database cluster writer endpoint address"
  type        = string
}

variable "db_name" {
  description = "Name of the target PostgreSQL database"
  type        = string
}

variable "db_username" {
  description = "Master database username"
  type        = string
}

variable "db_password_parameter_arn" {
  description = "SSM Parameter Store ARN containing the database master password"
  type        = string
}

variable "aws_region" {
  description = "AWS Region where logs and ECS tasks are hosted"
  type        = string
  default     = "us-east-2"
}