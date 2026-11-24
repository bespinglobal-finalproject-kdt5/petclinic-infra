module "seoul_vpc1" {
  source             = "./seoul-vpc1-service"
  availability_zones = var.availability_zones
  environment        = "prod"
  management_peer_id = aws_vpc_peering_connection.management_service.id
}

module "seoul_vpc2" {
  source            = "./seoul-vpc2-management"
  availability_zone = var.availability_zones[0]
  service_peer_id   = aws_vpc_peering_connection.management_service.id
}

module "edge" {
  source             = "./edge"
  certificate_region = local.cloudfront_certificate_region
  domain             = local.domain
  public_zone_id     = data.aws_route53_zone.public.zone_id
  vpc_id             = module.seoul_vpc1.service_vpc_id
  eks_alb_arn        = var.eks_alb_arn
}
