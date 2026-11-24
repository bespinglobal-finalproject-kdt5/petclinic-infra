output "service_vpc_id" {
  value = module.seoul_vpc1.service_vpc_id
}

output "management_vpc_id" {
  description = "Seoul management VPC 2."
  value       = module.seoul_vpc2.management_vpc_id
}

output "app_subnet_ids" {
  value = module.seoul_vpc1.app_subnet_ids
}

output "db_subnet_ids" {
  value = module.seoul_vpc1.db_subnet_ids
}

output "public_subnet_ids" {
  value = module.seoul_vpc1.public_subnet_ids
}

output "management_subnet_id" {
  description = "Private subnet for the Seoul management host and SSM endpoints."
  value       = module.seoul_vpc2.management_subnet_id
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

output "management_public_subnet_id" {
  value = module.seoul_vpc2.management_public_subnet_id
}

output "build_instance_id" {
  description = "Seoul build EC2 target for Systems Manager Session Manager."
  value       = module.seoul_vpc2.build_instance_id
}

output "management_instance_id" {
  description = "Private Seoul management EC2 target for Session Manager."
  value       = module.seoul_vpc2.management_instance_id
}
