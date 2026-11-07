output "alb_dns_name" {
  description = "Public DNS entry of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "URL of the created ECR container repository"
  value       = aws_ecr_repository.app.repository_url
}

output "task_security_group_id" {
  description = "Security Group ID assigned to the ECS tasks"
  value       = aws_security_group.task.id
}