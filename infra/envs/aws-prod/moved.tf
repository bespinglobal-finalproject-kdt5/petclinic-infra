# Move the former root edge resources into their environment module.
moved {
  from = data.aws_cloudfront_origin_request_policy.api
  to   = module.edge.data.aws_cloudfront_origin_request_policy.api
}

moved {
  from = data.aws_cloudfront_cache_policy.disabled
  to   = module.edge.data.aws_cloudfront_cache_policy.disabled
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
