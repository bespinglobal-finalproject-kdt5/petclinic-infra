locals {
  domain = "mission-critical.site"
}

data "aws_route53_zone" "public" {
  name         = local.domain
  private_zone = false
}

# Adopt the previously delegated zone, never create a second set of name servers.
import {
  to = module.cloudfront.aws_route53_zone.delegated
  id = data.aws_route53_zone.public.zone_id
}
