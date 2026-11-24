terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }
  }
}

locals {
  cloudfront_certificate_region = "us-east-1"
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
}

# Kept for states that still bind the original root ACM resources to this alias.
provider "aws" {
  alias               = "us_east_1"
  region              = local.cloudfront_certificate_region
  allowed_account_ids = [var.aws_account_id]
}

# Retain this alias until all resources formerly managed by module.osaka_observe
# have been destroyed and their provider binding has been cleared from state.
provider "aws" {
  alias               = "osaka"
  region              = "ap-northeast-3"
  allowed_account_ids = [var.aws_account_id]
  default_tags {
    tags = { project = "petclinic", environment = "prod", component = "management" }
  }
}
