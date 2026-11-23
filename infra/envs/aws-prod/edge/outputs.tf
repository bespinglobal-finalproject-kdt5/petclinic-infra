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

output "alb_security_group_id" {
  value = aws_security_group.origin.id
}

output "app_target_group_arns" {
  value = { for workload, group in aws_lb_target_group.app : workload => group.arn }
}
