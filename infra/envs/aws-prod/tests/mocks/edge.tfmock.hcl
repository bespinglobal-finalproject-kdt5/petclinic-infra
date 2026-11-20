mock_data "aws_route53_zone" {
  defaults = { zone_id = "ZMOCKPUBLIC" }
}
mock_data "aws_ec2_managed_prefix_list" {
  defaults = { id = "pl-0123456789abcdef0" }
}
mock_data "aws_cloudfront_cache_policy" {
  defaults = { id = "00000000-0000-4000-8000-000000000001" }
}

mock_resource "aws_acm_certificate" {
  override_during = plan
  defaults = {
    arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-4000-8000-000000000002"
    domain_validation_options = [{
      domain_name           = "mission-critical.site"
      resource_record_name  = "_mock.mission-critical.site"
      resource_record_type  = "CNAME"
      resource_record_value = "_mock.example.invalid."
    }]
  }
}
mock_resource "aws_route53_record" {
  override_during = plan
}
mock_resource "aws_lb" {
  override_during = plan
  defaults = {
    arn      = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:loadbalancer/app/mock/0000000000000001"
    dns_name = "internal-alb.example.invalid"
  }
}
mock_resource "aws_lb_listener" {
  override_during = plan
  defaults = {
    arn = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:listener/app/mock/0000000000000001/0000000000000002"
  }
}
mock_resource "aws_security_group" {
  override_during = plan
}
mock_resource "aws_cloudfront_vpc_origin" {
  override_during = plan
}
mock_resource "aws_cloudfront_distribution" {
  override_during = plan
  defaults = {
    domain_name    = "distribution.example.invalid"
    hosted_zone_id = "ZMOCKCLOUDFRONT"
  }
}
