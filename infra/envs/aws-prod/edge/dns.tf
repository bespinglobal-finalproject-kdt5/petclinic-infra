resource "aws_route53_zone" "delegated" {
  name    = var.domain
  comment = ""
  tags    = merge(local.edge_tags, { Name = "petclinic-prod-public-zone" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_acm_certificate" "viewer" {
  region            = var.certificate_region
  domain_name       = var.domain
  validation_method = "DNS"
  tags              = merge(local.edge_tags, { Name = "petclinic-prod-viewer-certificate" })

  lifecycle { create_before_destroy = true }
}

# One apex name, no SANs: exactly one validation option, no computed for_each keys.
locals {
  validation = one(aws_acm_certificate.viewer.domain_validation_options)
}

resource "aws_route53_record" "validation" {
  zone_id = var.public_zone_id
  name    = local.validation.resource_record_name
  type    = local.validation.resource_record_type
  records = [local.validation.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "viewer" {
  region                  = var.certificate_region
  certificate_arn         = aws_acm_certificate.viewer.arn
  validation_record_fqdns = [aws_route53_record.validation.fqdn]
}

resource "aws_route53_record" "viewer" {
  for_each = toset(["A", "AAAA"])
  zone_id  = var.public_zone_id
  name     = var.domain
  type     = each.value

  alias {
    name                   = aws_cloudfront_distribution.edge.domain_name
    zone_id                = aws_cloudfront_distribution.edge.hosted_zone_id
    evaluate_target_health = false
  }
}
