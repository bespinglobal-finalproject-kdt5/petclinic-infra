output "service_vpc_id" {
  value = module.network.service_vpc_id
}

output "management_vpc_id" {
  description = "Seoul management VPC 2, not the Osaka observability VPC."
  value       = module.network.management_vpc_id
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
  description = "Private subnet for future Seoul management access. No host is provisioned here yet."
  value       = module.network.management_subnet_id
}

output "public_url" {
  value = module.edge.public_url
}

output "cloudfront_distribution_id" {
  value = module.edge.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  value = module.edge.cloudfront_domain_name
}

output "internal_alb_dns_name" {
  description = "Private origin, not a public endpoint."
  value       = module.edge.internal_alb_dns_name
}

output "osaka_observe" {
  description = "Retained Osaka VPC and subnet."
  value = {
    vpc_id    = module.osaka_observe.vpc_id
    subnet_id = module.osaka_observe.subnet_id
  }
}
