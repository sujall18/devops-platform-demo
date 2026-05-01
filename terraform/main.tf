terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Populated via -backend-config or terraform.backend.hcl (never hardcode)
    # bucket         = "<your-state-bucket>"
    # key            = "devops-platform-demo/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "<your-lock-table>"
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "devops-platform-demo"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

module "networking" {
  source = "./modules/networking"

  project     = var.project
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
}

module "compute" {
  source = "./modules/compute"

  project          = var.project
  environment      = var.environment
  vpc_id           = module.networking.vpc_id
  public_subnet_id = module.networking.public_subnet_id
  instance_type    = var.instance_type
  key_name         = var.key_name
  my_ip_cidr       = var.my_ip_cidr
}
