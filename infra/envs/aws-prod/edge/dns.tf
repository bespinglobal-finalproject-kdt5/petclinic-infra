resource "aws_route53_zone" "delegated" {
  name    = var.domain
  comment = ""
  tags    = merge(local.edge_tags, { Name = "petclinic-prod-public-zone" })

  lifecycle {
    prevent_destroy = true
  }
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
