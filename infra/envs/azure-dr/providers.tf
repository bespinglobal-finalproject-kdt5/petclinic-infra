# 토폴로지 그림의 Azure 칸만 만든다. AWS RDS 는 이 폴더에 없다.
# Korea Central. 그림 라벨 "Azure · Korea Central (서울)".

terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.80"
    }
  }
}

# 4.x 는 subscription_id 가 없으면 plan 이 거절된다.
# 값은 terraform.tfvars 에만 둔다. 이 파일에 구독 ID를 적지 않는다.
provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}
