module "network" {
  source             = "./network"
  availability_zones = var.availability_zones
  environment        = "prod"
  retain_management  = true
}

module "osaka_observe" {
  source    = "./osaka-monitoring"
  providers = { aws = aws.osaka }
}

module "edge" {
  source             = "./edge"
  certificate_region = local.cloudfront_certificate_region
  domain             = local.domain
  public_zone_id     = data.aws_route53_zone.public.zone_id
  vpc_id             = module.network.service_vpc_id
  eks_alb_arn        = var.eks_alb_arn
}
