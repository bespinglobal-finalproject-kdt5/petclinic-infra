# Move the former root edge resources into their environment module.
moved {
  from = data.aws_ec2_managed_prefix_list.cloudfront
  to   = module.edge.data.aws_ec2_managed_prefix_list.cloudfront
}

moved {
  from = aws_security_group.origin
  to   = module.edge.aws_security_group.origin
}

moved {
  from = aws_vpc_security_group_ingress_rule.cloudfront_http
  to   = module.edge.aws_vpc_security_group_ingress_rule.cloudfront_http
}

moved {
  from = aws_lb.origin
  to   = module.edge.aws_lb.origin
}

moved {
  from = aws_lb_listener.http
  to   = module.edge.aws_lb_listener.http
}

moved {
  from = aws_lb_listener_rule.health
  to   = module.edge.aws_lb_listener_rule.health
}

moved {
  from = aws_lb_target_group.app
  to   = module.edge.aws_lb_target_group.app
}

moved {
  from = aws_lb_listener_rule.app
  to   = module.edge.aws_lb_listener_rule.app
}

moved {
  from = data.aws_cloudfront_origin_request_policy.api
  to   = module.edge.data.aws_cloudfront_origin_request_policy.api
}

moved {
  from = data.aws_cloudfront_cache_policy.disabled
  to   = module.edge.data.aws_cloudfront_cache_policy.disabled
}

moved {
  from = aws_cloudfront_vpc_origin.alb
  to   = module.edge.aws_cloudfront_vpc_origin.alb
}

moved {
  from = aws_cloudfront_distribution.edge
  to   = module.edge.aws_cloudfront_distribution.edge
}

moved {
  from = aws_route53_zone.delegated
  to   = module.edge.aws_route53_zone.delegated
}

moved {
  from = aws_acm_certificate.viewer
  to   = module.edge.aws_acm_certificate.viewer
}

moved {
  from = aws_route53_record.validation
  to   = module.edge.aws_route53_record.validation
}

moved {
  from = aws_acm_certificate_validation.viewer
  to   = module.edge.aws_acm_certificate_validation.viewer
}

moved {
  from = aws_route53_record.viewer
  to   = module.edge.aws_route53_record.viewer
}

moved {
  from = aws_vpc_peering_connection.seoul_osaka
  to   = module.osaka_observe.aws_vpc_peering_connection.seoul_osaka
}

moved {
  from = aws_vpc_peering_connection_accepter.osaka
  to   = module.osaka_observe.aws_vpc_peering_connection_accepter.osaka
}
