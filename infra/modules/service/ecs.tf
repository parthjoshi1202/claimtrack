# Task Security Group (Inbound port 8000 allowed strictly from ALB security group)
resource "aws_security_group" "task" {
  name        = "${var.name}-task-sg"
  description = "Security group for ClaimTrack ECS task instances"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-task-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  security_group_id            = aws_security_group.task.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Allow inbound application traffic from ALB security group"
}

resource "aws_vpc_security_group_egress_rule" "task_all_outbound" {
  security_group_id = aws_security_group.task.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow outbound traffic from ECS tasks for ECR pulls, SSM, and Aurora"
}

# CloudWatch Log Group with 1-day retention
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name}"
  retention_in_days = 1

  tags = {
    Name = "${var.name}-logs"
  }
  #checkov:skip=CKV_AWS_158:Uses default CloudWatch Logs encryption; KMS CMK omitted to avoid $1/mo key cost.
  #checkov:skip=CKV_AWS_338:Short log retention keeps CloudWatch storage near $0 in dev; 365+ days used in prod.
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.name}-cluster"
  #checkov:skip=CKV_AWS_65:Container Insights disabled in dev to avoid custom CloudWatch metrics charges under $20 spend cap.
}

# Fargate Task Definition (ARM64 Architecture)
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = var.name
      image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "DB_HOST", value = var.db_host },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_USER", value = var.db_username },
        { name = "AWS_REGION", value = var.aws_region }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = var.db_password_parameter_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "app" {
  name                              = "${var.name}-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.app.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60
  #checkov:skip=CKV_AWS_333:Public IP required on Fargate tasks in public subnets to pull ECR images without a ~$32/mo NAT Gateway.

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.name
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.http]
}