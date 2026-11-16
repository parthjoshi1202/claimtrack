# Security Group for Public Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Public ALB security group allowing HTTP inbound traffic"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_inbound" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0" # The ONLY rule in the stack open to 0.0.0.0/0
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  #checkov:skip=CKV_AWS_260:Public-facing dev ALB on HTTP port 80; no custom domain or ACM TLS cert in cost-capped dev.
  description = "Allow inbound HTTP traffic on port 80 to public ALB"
}

resource "aws_vpc_security_group_egress_rule" "alb_all_outbound" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow outbound traffic from ALB to ECS tasks"
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
  #checkov:skip=CKV_AWS_91:ALB access logs disabled in dev to avoid dedicated S3 log bucket and storage costs.
  #checkov:skip=CKV_AWS_150:Deletion protection disabled so nightly terraform destroy can tear down the ALB cleanly; enabled in prod.
  #checkov:skip=CKV2_AWS_20:HTTP-only listener in dev; no custom domain or ACM certificate provisioned.
  #checkov:skip=CKV2_AWS_28:AWS WAF costs ~$5+/mo base plus request fees, exceeding the $20 dev spend cap; enabled in prod.
  drop_invalid_header_fields = true

  tags = {
    Name = "${var.name}-alb"
  }
}

# Target Group (Must use target_type = "ip" for ECS Fargate)
resource "aws_lb_target_group" "app" {
  name        = "${var.name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  #checkov:skip=CKV_AWS_378:Internal ALB-to-ECS traffic is isolated inside private VPC security groups; TLS terminated at ALB in prod.

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name = "${var.name}-tg"
  }
}

# HTTP Listener on Port 80
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  #checkov:skip=CKV_AWS_2:HTTP-only listener in dev; no custom domain/ACM cert under $20 spend cap. Prod uses HTTPS.
  #checkov:skip=CKV_AWS_103:TLS 1.2 policy applies to HTTPS listeners; dev uses HTTP-only without an ACM cert.

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}