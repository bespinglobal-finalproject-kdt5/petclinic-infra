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
  value       = one(data.aws_lb.eks[*].dns_name)
}
