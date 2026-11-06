variable "name" {
  description = "Base name used for tagging resources (e.g., claimtrack-dev)"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where database security groups will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the RDS DB subnet group"
  type        = list(string)
}

variable "allowed_security_group_id" {
  description = "Security group ID of the application allowed to connect to PostgreSQL (port 5432)"
  type        = string
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version (e.g., 16.1 or 16.2)"
  type        = string
  default     = "16.8"
}