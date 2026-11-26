terraform {
  required_version = ">= 1.10, < 2.0"

  backend "s3" {
    bucket       = "petclinic-prod-tfstate-seoul"
    region       = "ap-northeast-2"
    key          = "petclinic/aws-prod/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
