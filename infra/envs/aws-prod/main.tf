locals {
  # Static outbound IP from the azure-dr NAT gateway.
  azure_dr_nat_public_ip = "4.230.9.84"
  domain                 = "mission-critical.site"
  management_host_cidr   = "${module.seoul_vpc2.management_private_ip}/32"
}

module "seoul_vpc1" {
  source               = "./seoul-vpc1-service"
  availability_zones   = var.availability_zones
  environment          = "prod"
  management_peer_id   = module.connectivity.peering_connection_id
  management_host_cidr = local.management_host_cidr

  azure_dr_nat_public_ip = local.azure_dr_nat_public_ip
  db_master_password     = var.db_master_password
}

module "seoul_vpc2" {
  source            = "./seoul-vpc2-management"
  availability_zone = var.availability_zones[0]
  service_peer_id   = module.connectivity.peering_connection_id
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

module "cloudfront" {
  source             = "./cloudfront"
  certificate_region = local.cloudfront_certificate_region
  domain             = local.domain
  vpc_id             = module.seoul_vpc1.service_vpc_id
  eks_alb_arn        = var.eks_alb_arn
  cloudfront_enabled = var.cloudfront_enabled
}

module "connectivity" {
  source                       = "./connectivity"
  management_vpc_id            = module.seoul_vpc2.management_vpc_id
  service_vpc_id               = module.seoul_vpc1.service_vpc_id
  management_security_group_id = module.seoul_vpc2.management_security_group_id
  rds_security_group_id        = module.seoul_vpc1.rds_security_group_id
  eks_security_group_id        = module.eks.cluster_security_group_id
  management_host_cidr         = local.management_host_cidr
  azure_dr_nat_public_ip       = local.azure_dr_nat_public_ip
}
