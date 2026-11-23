mock_data "aws_route53_zone" {
  defaults = { zone_id = "ZMOCKPUBLIC" }
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
mock_data "aws_lb" {
  defaults = {
    dns_name           = "internal-eks.example.invalid"
    internal           = true
    load_balancer_type = "application"
    vpc_id             = "vpc-00000000000000001"
  }
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
