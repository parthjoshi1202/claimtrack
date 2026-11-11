terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket       = "claimtrack-tfstate-895280308319"
    key          = "dev/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      Project = "claimtrack"
      Owner   = "parth"
    }
  }
}

# 1. Base Networking Module
module "network" {
  source = "../../modules/network"
  name   = "claimtrack-dev"
}

# 2. Service Module (ECR, ALB, ECS Fargate Task & Service)
module "service" {
  source                    = "../../modules/service"
  name                      = "claimtrack-dev"
  vpc_id                    = module.network.vpc_id
  public_subnet_ids         = module.network.public_subnet_ids
  image_tag                 = var.image_tag
  db_host                   = module.database.endpoint
  db_name                   = module.database.db_name
  db_username               = module.database.username
  db_password_parameter_arn = module.database.password_parameter_arn
  aws_region                = "us-east-2"
}

# 3. Database Module (Aurora Serverless v2 PostgreSQL)
module "database" {
  source                    = "../../modules/database"
  name                      = "claimtrack-dev"
  vpc_id                    = module.network.vpc_id
  private_subnet_ids        = module.network.private_subnet_ids
  allowed_security_group_id = module.service.task_security_group_id
  engine_version            = "16.15"
}

# Root Outputs
output "application_url" {
  description = "Public HTTP endpoint for the ClaimTrack application"
  value       = "http://${module.service.alb_dns_name}"
}

variable "image_tag" {
  type    = string
  default = "v1"
}

output "ecr_repository_url" {
  value = module.service.ecr_repository_url
}

output "db_endpoint" {
  description = "Aurora Cluster Writer Endpoint"
  value       = module.database.endpoint
}