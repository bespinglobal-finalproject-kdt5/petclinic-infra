module "seoul_vpc1" {
  source               = "./seoul-vpc1-service"
  availability_zones   = var.availability_zones
  environment          = "prod"
  management_peer_id   = aws_vpc_peering_connection.management_service.id
  management_host_cidr = local.management_host_cidr

  db_master_password = var.db_master_password
}

module "seoul_vpc2" {
  source            = "./seoul-vpc2-management"
  availability_zone = var.availability_zones[0]
  service_peer_id   = aws_vpc_peering_connection.management_service.id
}

module "eks" {
  source               = "./eks"
  aws_region           = var.aws_region
  aws_account_id       = var.aws_account_id
  service_vpc_id       = module.seoul_vpc1.service_vpc_id
  app_subnet_ids       = module.seoul_vpc1.app_subnet_ids
  cluster_admins       = local.cluster_admins
  cluster_name         = var.cluster_name
  kubernetes_version   = var.kubernetes_version
  node_instance_type   = var.node_instance_type
  node_scaling         = var.node_scaling
  node_release_version = var.node_release_version
  addon_versions       = var.addon_versions
}

module "edge" {
  source             = "./cloudfront"
  certificate_region = local.cloudfront_certificate_region
  domain             = local.domain
  public_zone_id     = data.aws_route53_zone.public.zone_id
  vpc_id             = module.seoul_vpc1.service_vpc_id
  eks_alb_arn        = var.eks_alb_arn
}
