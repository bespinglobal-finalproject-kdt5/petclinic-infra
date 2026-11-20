mock_provider "aws" {
  source = "./tests/mocks"
}

mock_provider "aws" {
  alias  = "us_east_1"
  source = "./tests/mocks"
}

# Synthetic account and Seoul AZs for mock plans only.
variables {
  aws_account_id     = "123456789012"
  aws_region         = "ap-northeast-2"
  availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
}

run "production_outputs" {
  command = plan
  assert {
    condition = (
      output.service_vpc_id == module.network.service_vpc_id && output.management_vpc_id == module.network.management_vpc_id &&
      output.management_subnet_id == module.network.management_subnet_id &&
      output.app_subnet_ids == module.network.app_subnet_ids && output.db_subnet_ids == module.network.db_subnet_ids &&
      output.public_subnet_ids == module.network.public_subnet_ids
    )
    error_message = "The production root must expose all six module outputs without reordering."
  }
}

run "reject_bad_account" {
  command = plan
  variables { aws_account_id = "12345678901x" }
  expect_failures = [var.aws_account_id]
}

run "reject_bad_region" {
  command = plan
  variables { aws_region = "Seoul" }
  expect_failures = [var.aws_region]
}

run "reject_duplicate_zones" {
  command = plan
  variables { availability_zones = ["ap-northeast-2a", "ap-northeast-2a"] }
  expect_failures = [var.availability_zones]
}

run "reject_single_zone" {
  command = plan
  variables { availability_zones = ["ap-northeast-2a"] }
  expect_failures = [var.availability_zones]
}

run "reject_wrong_region_zone" {
  command = plan
  variables { availability_zones = ["ap-northeast-2a", "ap-northeast-99c"] }
  expect_failures = [var.availability_zones]
}

run "public_edge" {
  command = plan

  assert {
    condition = (
      aws_lb.origin.internal && aws_lb.origin.load_balancer_type == "application" &&
      aws_lb.origin.subnets == toset(module.network.app_subnet_ids) &&
      one(aws_lb.origin.security_groups) == aws_security_group.origin.id && aws_security_group.origin.vpc_id == module.network.service_vpc_id &&
      aws_vpc_security_group_ingress_rule.cloudfront_http.security_group_id == aws_security_group.origin.id &&
      aws_vpc_security_group_ingress_rule.cloudfront_http.prefix_list_id == data.aws_ec2_managed_prefix_list.cloudfront.id &&
      data.aws_ec2_managed_prefix_list.cloudfront.name == "com.amazonaws.global.cloudfront.origin-facing" &&
      aws_vpc_security_group_ingress_rule.cloudfront_http.ip_protocol == "tcp" &&
      aws_vpc_security_group_ingress_rule.cloudfront_http.from_port == 80 && aws_vpc_security_group_ingress_rule.cloudfront_http.to_port == 80
    )
    error_message = "The private app-subnet ALB must admit HTTP from the CloudFront origin-facing prefix list."
  }
  assert {
    condition = (
      aws_lb_listener.http.load_balancer_arn == aws_lb.origin.arn && aws_lb_listener.http.protocol == "HTTP" && aws_lb_listener.http.port == 80 &&
      aws_lb_listener.http.default_action[0].fixed_response[0].status_code == "404" &&
      aws_lb_listener_rule.health.listener_arn == aws_lb_listener.http.arn &&
      one(one(aws_lb_listener_rule.health.condition).path_pattern[0].values) == "/health" &&
      aws_lb_listener_rule.health.action[0].fixed_response[0].status_code == "200"
    )
    error_message = "Only /health should return the fixed success response."
  }
  assert {
    condition = (
      aws_cloudfront_vpc_origin.alb.vpc_origin_endpoint_config[0].arn == aws_lb.origin.arn &&
      aws_cloudfront_vpc_origin.alb.vpc_origin_endpoint_config[0].origin_protocol_policy == "http-only" &&
      aws_cloudfront_vpc_origin.alb.vpc_origin_endpoint_config[0].http_port == aws_lb_listener.http.port &&
      one(aws_cloudfront_distribution.edge.origin).vpc_origin_config[0].vpc_origin_id == aws_cloudfront_vpc_origin.alb.id &&
      one(aws_cloudfront_distribution.edge.origin).domain_name == aws_lb.origin.dns_name &&
      aws_cloudfront_distribution.edge.default_cache_behavior[0].target_origin_id == one(aws_cloudfront_distribution.edge.origin).origin_id &&
      aws_cloudfront_distribution.edge.default_cache_behavior[0].cache_policy_id == data.aws_cloudfront_cache_policy.disabled.id &&
      data.aws_cloudfront_cache_policy.disabled.name == "Managed-CachingDisabled"
    )
    error_message = "Uncached requests must use the HTTP VPC origin, not a public custom origin."
  }
  assert {
    condition = (
      aws_cloudfront_distribution.edge.enabled && aws_cloudfront_distribution.edge.is_ipv6_enabled &&
      one(aws_cloudfront_distribution.edge.aliases) == "mission-critical.site" &&
      aws_cloudfront_distribution.edge.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https" &&
      aws_cloudfront_distribution.edge.viewer_certificate[0].minimum_protocol_version == "TLSv1.2_2021" &&
      aws_cloudfront_distribution.edge.viewer_certificate[0].acm_certificate_arn == aws_acm_certificate_validation.viewer.certificate_arn &&
      aws_acm_certificate_validation.viewer.certificate_arn == aws_acm_certificate.viewer.arn &&
      aws_acm_certificate.viewer.domain_name == "mission-critical.site" && aws_acm_certificate.viewer.validation_method == "DNS" &&
      one(aws_acm_certificate_validation.viewer.validation_record_fqdns) == aws_route53_record.validation.fqdn &&
      aws_route53_record.validation.zone_id == data.aws_route53_zone.public.zone_id && aws_route53_record.validation.type == "CNAME" &&
      aws_route53_record.validation.name == one(aws_acm_certificate.viewer.domain_validation_options).resource_record_name &&
      one(aws_route53_record.validation.records) == one(aws_acm_certificate.viewer.domain_validation_options).resource_record_value
    )
    error_message = "HTTPS viewers require the DNS-validated apex certificate."
  }
  assert {
    condition = (
      data.aws_route53_zone.public.name == "mission-critical.site" && !data.aws_route53_zone.public.private_zone &&
      toset(keys(aws_route53_record.viewer)) == toset(["A", "AAAA"]) &&
      alltrue([for t, r in aws_route53_record.viewer : r.type == t && r.name == "mission-critical.site" &&
        r.zone_id == data.aws_route53_zone.public.zone_id && one(r.alias).name == aws_cloudfront_distribution.edge.domain_name &&
        one(r.alias).zone_id == aws_cloudfront_distribution.edge.hosted_zone_id && !one(r.alias).evaluate_target_health
      ])
    )
    error_message = "Both public apex aliases must point to the distribution, not the ALB."
  }
}
