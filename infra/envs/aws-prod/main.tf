module "seoul_vpc1" {
  source                     = "./seoul-vpc1-service"
  availability_zones         = var.availability_zones
  environment                = "prod"
  db_app_password            = var.db_app_password
  eks_node_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  management_peer_id         = aws_vpc_peering_connection.management_service.id
  osaka_peer = {
    id          = module.osaka_observe.peering_id
    subnet_cidr = module.osaka_observe.subnet_cidr
  }
}

module "seoul_vpc2" {
  source            = "./seoul-vpc2-management"
  availability_zone = var.availability_zones[0]
  service_peer_id   = aws_vpc_peering_connection.management_service.id
}

module "osaka_observe" {
  source          = "./osaka-monitoring"
  providers       = { aws = aws.osaka }
  seoul_region    = var.aws_region
  seoul_vpc_id    = module.seoul_vpc1.service_vpc_id
  seoul_app_cidrs = module.seoul_vpc1.app_subnet_cidrs
}

module "edge" {
  source             = "./edge"
  certificate_region = local.cloudfront_certificate_region
  domain             = local.domain
  public_zone_id     = data.aws_route53_zone.public.zone_id
  vpc_id             = module.seoul_vpc1.service_vpc_id
  eks_alb_arn        = var.eks_alb_arn
}
