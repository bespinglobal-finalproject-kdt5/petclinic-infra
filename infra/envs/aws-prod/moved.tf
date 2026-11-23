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

# Preserve Seoul resource IDs across the VPC module split.
moved {
  from = module.network.aws_vpc.service
  to   = module.seoul_vpc1.aws_vpc.service
}

moved {
  from = module.network.aws_subnet.service
  to   = module.seoul_vpc1.aws_subnet.service
}

moved {
  from = module.network.aws_internet_gateway.service
  to   = module.seoul_vpc1.aws_internet_gateway.service
}

moved {
  from = module.network.aws_eip.app_nat
  to   = module.seoul_vpc1.aws_eip.app_nat
}

moved {
  from = module.network.aws_nat_gateway.public_1
  to   = module.seoul_vpc1.aws_nat_gateway.public_1
}

moved {
  from = module.network.aws_route_table.service_public
  to   = module.seoul_vpc1.aws_route_table.service_public
}

moved {
  from = module.network.aws_route_table.service_app
  to   = module.seoul_vpc1.aws_route_table.service_app
}

moved {
  from = module.network.aws_route_table.service_private
  to   = module.seoul_vpc1.aws_route_table.service_private
}

moved {
  from = module.network.aws_route_table_association.service
  to   = module.seoul_vpc1.aws_route_table_association.service
}

moved {
  from = module.network.aws_vpc.management
  to   = module.network.aws_vpc.management[0]
}

moved {
  from = module.network.aws_vpc.management[0]
  to   = module.seoul_vpc2.aws_vpc.management
}

moved {
  from = module.network.aws_subnet.management
  to   = module.network.aws_subnet.management[0]
}

moved {
  from = module.network.aws_subnet.management[0]
  to   = module.seoul_vpc2.aws_subnet.management
}

moved {
  from = module.network.aws_route_table.management
  to   = module.network.aws_route_table.management[0]
}

moved {
  from = module.network.aws_route_table.management[0]
  to   = module.seoul_vpc2.aws_route_table.management
}

moved {
  from = module.network.aws_route_table_association.management
  to   = module.network.aws_route_table_association.management[0]
}

moved {
  from = module.network.aws_route_table_association.management[0]
  to   = module.seoul_vpc2.aws_route_table_association.management
}

moved {
  from = module.network.aws_subnet.management_public[0]
  to   = module.seoul_vpc2.aws_subnet.management_public
}

moved {
  from = module.network.aws_internet_gateway.management[0]
  to   = module.seoul_vpc2.aws_internet_gateway.management
}

moved {
  from = module.network.aws_route_table.management_public[0]
  to   = module.seoul_vpc2.aws_route_table.management_public
}

moved {
  from = module.network.aws_route_table_association.management_public[0]
  to   = module.seoul_vpc2.aws_route_table_association.management_public
}

moved {
  from = module.build_server
  to   = module.seoul_vpc2.module.build_server
}
