locals {
  edge_tags = { project = "petclinic", environment = "prod", component = "network" }
}

data "aws_cloudfront_origin_request_policy" "api" {
  name = "Managed-AllViewerExceptHostHeader"
}

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_lb" "eks" {
  count = var.eks_alb_arn == null ? 0 : 1
  arn   = var.eks_alb_arn

  lifecycle {
    postcondition {
      condition     = self.internal && self.load_balancer_type == "application" && self.vpc_id == var.vpc_id
      error_message = "The EKS origin must be an internal Application Load Balancer in the Seoul service VPC."
    }
  }
}

resource "aws_cloudfront_vpc_origin" "eks" {
  count = length(data.aws_lb.eks)

  vpc_origin_endpoint_config {
    name                   = "petclinic-prod-eks-alb"
    arn                    = data.aws_lb.eks[count.index].arn
    http_port              = 80
    https_port             = 443 # Endpoint schema requires this even for http-only.
    origin_protocol_policy = "http-only"
    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
  tags = merge(local.edge_tags, { Name = "petclinic-prod-eks-vpc-origin" })
}

resource "aws_cloudfront_distribution" "edge" {
  enabled         = var.eks_alb_arn != null
  is_ipv6_enabled = true
  aliases         = [var.domain]
  tags            = merge(local.edge_tags, { Name = "petclinic-prod-edge-distribution" })

  origin {
    # CloudFront requires one origin even while disabled. No DNS record is created for this name.
    domain_name = var.eks_alb_arn == null ? "origin-pending.${var.domain}" : data.aws_lb.eks[0].dns_name
    origin_id   = "internal-alb"

    dynamic "vpc_origin_config" {
      for_each = aws_cloudfront_vpc_origin.eks
      content {
        vpc_origin_id = vpc_origin_config.value.id
      }
    }

    dynamic "custom_origin_config" {
      for_each = var.eks_alb_arn == null ? [1] : []
      content {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior {
    target_origin_id       = "internal-alb"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.disabled.id
    viewer_protocol_policy = "redirect-to-https"
  }

  ordered_cache_behavior {
    path_pattern             = "/petclinic/api/*"
    target_origin_id         = "internal-alb"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.api.id
    viewer_protocol_policy   = "https-only"
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
