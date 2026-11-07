terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# 1. Random Password Generation
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 2. Store Database Password Securely in SSM Parameter Store
resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.name}/db_password"
  description = "Master password for ClaimTrack PostgreSQL Aurora database"
  type        = "SecureString"
  value       = random_password.db.result
}

# 3. DB Subnet Group (Private Subnets Only)
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.name}-db-subnet-group"
  }
}

# 4. Database Security Group and Restricted Ingress Rule
resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "Security group for ClaimTrack Aurora PostgreSQL cluster"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-db-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_app" {
  security_group_id            = aws_security_group.db.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.allowed_security_group_id
}

# 5. Aurora Serverless v2 PostgreSQL Cluster
resource "aws_rds_cluster" "this" {
  cluster_identifier   = "${var.name}-db-cluster"
  engine               = "aurora-postgresql"
  engine_mode          = "provisioned"
  engine_version       = var.engine_version
  database_name        = "claims"
  master_username      = "claimtrack"
  master_password      = random_password.db.result
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [
    aws_security_group.db.id
  ]

  storage_encrypted       = true
  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  serverlessv2_scaling_configuration {
    min_capacity             = 0
    max_capacity             = 2
    seconds_until_auto_pause = 300
  }

  tags = {
    Name = "${var.name}-db-cluster"
  }
}

# 6. Primary Cluster Writer Instance
resource "aws_rds_cluster_instance" "writer" {
  cluster_identifier  = aws_rds_cluster.this.id
  instance_class      = "db.serverless"
  engine              = aws_rds_cluster.this.engine
  engine_version      = aws_rds_cluster.this.engine_version
  publicly_accessible = false

  tags = {
    Name = "${var.name}-db-writer"
  }
}