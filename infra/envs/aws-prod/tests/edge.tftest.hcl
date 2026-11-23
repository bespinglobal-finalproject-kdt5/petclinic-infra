mock_provider "aws" {
  source = "./tests/mocks"
}

variables {
  certificate_region = "us-east-1"
  domain             = "mission-critical.site"
  public_zone_id     = "ZMOCKPUBLIC"
  vpc_id             = "vpc-00000000000000001"
}

run "waiting_for_eks_origin" {
  command = plan
  module { source = "./edge" }

  assert {
    condition = (
      !aws_cloudfront_distribution.edge.enabled && length(aws_cloudfront_vpc_origin.eks) == 0 &&
      one(aws_cloudfront_distribution.edge.origin).domain_name == "origin-pending.mission-critical.site" &&
      length(one(aws_cloudfront_distribution.edge.origin).vpc_origin_config) == 0 &&
      one(one(aws_cloudfront_distribution.edge.origin).custom_origin_config).origin_protocol_policy == "https-only" &&
      output.internal_alb_dns_name == null
    )
    error_message = "Keep the distribution disabled with an unserved origin until the EKS ALB exists."
  }
  assert {
    condition = (
      aws_cloudfront_distribution.edge.is_ipv6_enabled &&
      one(aws_cloudfront_distribution.edge.aliases) == "mission-critical.site" &&
      aws_cloudfront_distribution.edge.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https" &&
      aws_cloudfront_distribution.edge.viewer_certificate[0].minimum_protocol_version == "TLSv1.2_2021" &&
      aws_cloudfront_distribution.edge.viewer_certificate[0].acm_certificate_arn == aws_acm_certificate_validation.viewer.certificate_arn &&
      aws_acm_certificate_validation.viewer.certificate_arn == aws_acm_certificate.viewer.arn &&
      aws_acm_certificate.viewer.region == "us-east-1" && aws_acm_certificate_validation.viewer.region == "us-east-1" &&
      aws_acm_certificate.viewer.domain_name == "mission-critical.site" && aws_acm_certificate.viewer.validation_method == "DNS" &&
      one(aws_acm_certificate_validation.viewer.validation_record_fqdns) == aws_route53_record.validation.fqdn &&
      aws_route53_record.validation.zone_id == var.public_zone_id && aws_route53_record.validation.type == "CNAME" &&
      aws_route53_record.validation.name == one(aws_acm_certificate.viewer.domain_validation_options).resource_record_name &&
      one(aws_route53_record.validation.records) == one(aws_acm_certificate.viewer.domain_validation_options).resource_record_value
    )
    error_message = "HTTPS viewers require the DNS-validated apex certificate."
  }
  assert {
    condition = (
      aws_route53_zone.delegated.name == var.domain &&
      toset(keys(aws_route53_record.viewer)) == toset(["A", "AAAA"]) &&
      alltrue([for t, r in aws_route53_record.viewer : r.type == t && r.name == "mission-critical.site" &&
        r.zone_id == var.public_zone_id && one(r.alias).name == aws_cloudfront_distribution.edge.domain_name &&
        one(r.alias).zone_id == aws_cloudfront_distribution.edge.hosted_zone_id && !one(r.alias).evaluate_target_health
      ])
    )
    error_message = "Both public apex aliases must point to the distribution, not the ALB."
  }
  assert {
    condition = (
      length(aws_cloudfront_distribution.edge.default_cache_behavior[0].function_association) == 0 &&
      length(aws_cloudfront_distribution.edge.ordered_cache_behavior[0].function_association) == 0 &&
      aws_cloudfront_distribution.edge.ordered_cache_behavior[0].viewer_protocol_policy == "https-only" &&
      aws_cloudfront_distribution.edge.ordered_cache_behavior[0].path_pattern == "/petclinic/api/*" &&
      contains(aws_cloudfront_distribution.edge.ordered_cache_behavior[0].allowed_methods, "POST") &&
      !contains(aws_cloudfront_distribution.edge.default_cache_behavior[0].allowed_methods, "POST")
    )
    error_message = "The demo UI and API must not have a viewer gate; writes remain API-only."
  }
}

run "external_eks_origin" {
  command = plan
  module { source = "./edge" }
  variables {
    eks_alb_arn = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:loadbalancer/app/eks/0123456789abcdef"
  }
  assert {
    condition = (
      aws_cloudfront_distribution.edge.enabled && length(aws_cloudfront_vpc_origin.eks) == 1 &&
      one(aws_cloudfront_vpc_origin.eks[0].vpc_origin_endpoint_config).arn == var.eks_alb_arn &&
      one(aws_cloudfront_vpc_origin.eks[0].vpc_origin_endpoint_config).origin_protocol_policy == "http-only" &&
      one(aws_cloudfront_distribution.edge.origin).domain_name == data.aws_lb.eks[0].dns_name &&
      length(one(aws_cloudfront_distribution.edge.origin).custom_origin_config) == 0 &&
      one(one(aws_cloudfront_distribution.edge.origin).vpc_origin_config).vpc_origin_id == aws_cloudfront_vpc_origin.eks[0].id
    )
    error_message = "Route CloudFront to the supplied EKS ALB using a private VPC origin."
  }
}

run "reject_public_eks_origin" {
  command = plan
  module { source = "./edge" }
  variables {
    eks_alb_arn = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:loadbalancer/app/public/0123456789abcdef"
  }
  override_data {
    target = data.aws_lb.eks[0]
    values = { internal = false }
  }
  expect_failures = [data.aws_lb.eks[0]]
}
