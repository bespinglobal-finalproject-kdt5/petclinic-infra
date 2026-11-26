locals {
  private_subnet_ids = toset(var.app_subnet_ids)
}

data "aws_vpc" "service" {
  id = var.service_vpc_id
}

data "aws_subnet" "private" {
  for_each = {
    app_1 = var.app_subnet_ids[0]
    app_2 = var.app_subnet_ids[1]
  }
  id = each.value
}
