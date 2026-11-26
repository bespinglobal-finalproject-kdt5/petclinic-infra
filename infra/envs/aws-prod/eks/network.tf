locals {
  private_subnet_ids = toset(var.app_subnet_ids)
}
