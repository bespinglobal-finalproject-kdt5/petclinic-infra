terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
}

provider "aws" {
  alias               = "us_east_1"
  region              = "us-east-1"
  allowed_account_ids = [var.aws_account_id]
}

module "network" {
  source             = "../../modules/aws-network"
  availability_zones = var.availability_zones
  environment        = "prod"
  retain_management  = !var.retire_seoul_management_vpc
  observe_peer = {
    id          = aws_vpc_peering_connection_accepter.osaka.id
    subnet_cidr = module.osaka_observe.subnet_cidr
  }
}
