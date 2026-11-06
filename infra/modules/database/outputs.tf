output "endpoint" {
  description = "Writer endpoint for the Aurora PostgreSQL cluster"
  value       = aws_rds_cluster.this.endpoint
}

output "port" {
  description = "Port on which the database accepts connections"
  value       = aws_rds_cluster.this.port
}

output "db_name" {
  description = "Name of the initial database created upon cluster instantiation"
  value       = aws_rds_cluster.this.database_name
}

output "username" {
  description = "Master username for database access"
  value       = aws_rds_cluster.this.master_username
}

output "password_parameter_arn" {
  description = "ARN of the SSM Parameter holding the master database password"
  value       = aws_ssm_parameter.db_password.arn
}