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

module "edge" {
  source             = "./edge"
  certificate_region = local.cloudfront_certificate_region
  domain             = local.domain
  public_zone_id     = data.aws_route53_zone.public.zone_id
  vpc_id             = module.network.service_vpc_id
  app_subnet_ids     = module.network.app_subnet_ids
}
