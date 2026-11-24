data "aws_ec2_managed_prefix_list" "cloudfront_origin" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}
output "cloudfront_origin_prefix_list_id" {
  value = data.aws_ec2_managed_prefix_list.cloudfront_origin.id
}