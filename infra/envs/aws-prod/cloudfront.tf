data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

resource "aws_cloudfront_vpc_origin" "alb" {
  vpc_origin_endpoint_config {
    name                   = "petclinic-prod-alb"
    arn                    = aws_lb.origin.arn
    http_port              = 80
    https_port             = 443 # Endpoint schema requires this even for http-only.
    origin_protocol_policy = "http-only"
    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
  tags = merge(local.edge_tags, { Name = "petclinic-prod-alb-vpc-origin" })

  # The endpoint ARN alone does not imply a working listener or admission rule.
  depends_on = [aws_lb_listener_rule.health, aws_vpc_security_group_ingress_rule.cloudfront_http]
}

resource "aws_cloudfront_distribution" "edge" {
  enabled         = true
  is_ipv6_enabled = true
  aliases         = [local.domain]
  tags            = merge(local.edge_tags, { Name = "petclinic-prod-edge-distribution" })

  origin {
    domain_name = aws_lb.origin.dns_name
    origin_id   = "internal-alb"
    vpc_origin_config {
      vpc_origin_id = aws_cloudfront_vpc_origin.alb.id
    }
  }

  default_cache_behavior {
    target_origin_id       = "internal-alb"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.disabled.id
    viewer_protocol_policy = "redirect-to-https"
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.viewer_gate.arn
    }
  }

  ordered_cache_behavior {
    path_pattern             = "/petclinic/api/*"
    target_origin_id         = "internal-alb"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.api.id
    viewer_protocol_policy   = "https-only"
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.viewer_gate.arn
    }
  }

  custom_error_response {
    error_code            = 404
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.viewer.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
