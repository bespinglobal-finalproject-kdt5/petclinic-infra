terraform {
  required_version = ">= 1.11, < 2.0"

  backend "s3" {
    bucket       = "petclinic-prod-tfstate-osaka"
    region       = "ap-northeast-3"
    key          = "petclinic/aws-prod/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
