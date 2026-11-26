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
  description = "DNS name of the configured EKS-managed ALB."
  value       = local.alb_dns_name
}

output "alb_certificate_arn" {
  description = "Validated regional certificate for the internal HTTPS listener."
  value       = aws_acm_certificate_validation.alb.certificate_arn
}

output "cloudfront_origin_prefix_list_id" {
  value = data.aws_ec2_managed_prefix_list.cloudfront_origin.id
}
