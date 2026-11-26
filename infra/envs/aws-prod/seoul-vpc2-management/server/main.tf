terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

locals {
  build_name      = "petclinic-prod-build"
  management_name = "petclinic-prod-management"
  tags            = { project = "petclinic", environment = "prod", component = "management" }
}
