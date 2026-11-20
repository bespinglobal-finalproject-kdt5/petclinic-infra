output "service_vpc_id" {
  value = module.network.service_vpc_id
}

output "management_vpc_id" {
  value = module.network.management_vpc_id
}

output "app_subnet_ids" {
  value = module.network.app_subnet_ids
}

output "db_subnet_ids" {
  value = module.network.db_subnet_ids
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "management_subnet_id" {
  value = module.network.management_subnet_id
}
