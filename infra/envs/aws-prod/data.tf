data "aws_route53_zone" "public" {
  name         = local.domain
  private_zone = false
}
