terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

module "network" {
  source = "../../modules/network"
  name   = "claimtrack-dev"
}