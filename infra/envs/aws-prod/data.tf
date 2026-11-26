data "aws_route53_zone" "public" {
  name         = local.domain
  private_zone = false
}

data "aws_ec2_managed_prefix_list" "cloudfront_origin" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}
