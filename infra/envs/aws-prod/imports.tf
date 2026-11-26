# Adopt the previously delegated zone, never create a second set of name servers.
import {
  to = module.cloudfront.aws_route53_zone.delegated
  id = data.aws_route53_zone.public.zone_id
}
