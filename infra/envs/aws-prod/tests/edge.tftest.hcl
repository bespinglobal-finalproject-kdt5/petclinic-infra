mock_provider "aws" {
  source = "./tests/mocks"
}

run "public_edge" {
  command = plan
  module { source = "./edge" }
  variables {
    certificate_region          = "us-east-1"
    domain                      = "mission-critical.site"
    public_zone_id              = "ZMOCKPUBLIC"
    vpc_id                      = "vpc-00000000000000001"
    app_subnet_ids              = ["subnet-00000000000000001", "subnet-00000000000000002"]
    cluster_security_group_id   = "sg-00000000000000001"
    node_autoscaling_group_name = "mock-app-nodes"
  }

  assert {
    condition = alltrue([for tags in [
      aws_route53_zone.delegated.tags, aws_acm_certificate.viewer.tags, aws_security_group.origin.tags,
      aws_vpc_security_group_ingress_rule.cloudfront_http.tags, aws_lb.origin.tags, aws_lb_listener.http.tags,
      aws_lb_listener_rule.health.tags, aws_cloudfront_vpc_origin.alb.tags, aws_cloudfront_distribution.edge.tags
    ] : tags.project == "petclinic" && tags.environment == "prod" && tags.component == "network" && startswith(tags.Name, "petclinic-prod-")])
    error_message = "All taggable edge resources must carry the shared production network tags and a Name."
  }

  assert {
    condition = (
      aws_lb.origin.internal && aws_lb.origin.load_balancer_type == "application" &&
      aws_lb.origin.subnets == toset(var.app_subnet_ids) &&
      one(aws_lb.origin.security_groups) == aws_security_group.origin.id && aws_security_group.origin.vpc_id == var.vpc_id &&
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
  assert {
    condition = alltrue([for workload in ["web", "api"] :
      aws_autoscaling_attachment.app[workload].autoscaling_group_name == var.node_autoscaling_group_name &&
      aws_vpc_security_group_egress_rule.alb_to_node[workload].referenced_security_group_id == var.cluster_security_group_id &&
      aws_vpc_security_group_ingress_rule.node_from_alb[workload].security_group_id == var.cluster_security_group_id
    ])
    error_message = "The ALB must use the EKS node group and security group for both workloads."
  }
}
