module "network" {
  source             = "./network"
  availability_zones = var.availability_zones
  environment        = "prod"
  retain_management  = true # Seoul VPC 2 is independent of Osaka observability.
  observe_peer = {
    id          = module.osaka_observe.peering_id
    subnet_cidr = module.osaka_observe.subnet_cidr
  }
}

module "osaka_observe" {
  source          = "./osaka-monitoring"
  providers       = { aws = aws.osaka }
  my_ip           = var.osaka_admin_ipv4
  key_name        = var.osaka_key_name
  seoul_region    = var.aws_region
  seoul_vpc_id    = module.network.service_vpc_id
  seoul_app_cidrs = module.network.app_subnet_cidrs
}

module "eks" {
  source     = "./eks"
  name       = "petclinic-prod"
  tags       = { project = "petclinic", environment = "prod", component = "app" }
  subnet_ids = module.network.app_subnet_ids

  kubernetes_version = "1.36"
  ami_type           = "AL2023_x86_64_STANDARD"
  # Pin both builds here after validating them in Seoul.
  node_ami_release = null
  vpc_cni_version  = null
}

module "database" {
  source                    = "./database"
  vpc_id                    = module.network.service_vpc_id
  db_subnet_ids             = module.network.db_subnet_ids
  cluster_security_group_id = module.eks.cluster_security_group_id
}

module "edge" {
  source                      = "./edge"
  certificate_region          = local.cloudfront_certificate_region
  domain                      = local.domain
  public_zone_id              = data.aws_route53_zone.public.zone_id
  vpc_id                      = module.network.service_vpc_id
  app_subnet_ids              = module.network.app_subnet_ids
  cluster_security_group_id   = module.eks.cluster_security_group_id
  node_autoscaling_group_name = module.eks.node_autoscaling_group_name
}
