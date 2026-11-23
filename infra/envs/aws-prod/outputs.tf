output "service_vpc_id" {
  value = module.network.service_vpc_id
}

output "management_vpc_id" {
  value = var.retire_seoul_management_vpc ? module.osaka_observe.vpc_id : module.network.management_vpc_id
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
  value = var.retire_seoul_management_vpc ? module.osaka_observe.subnet_id : module.network.management_subnet_id
}

output "public_url" {
  value = "https://${aws_route53_record.viewer["A"].fqdn}"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.edge.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.edge.domain_name
}

output "internal_alb_dns_name" {
  description = "Private origin, not a public endpoint."
  value       = aws_lb.origin.dns_name
}
