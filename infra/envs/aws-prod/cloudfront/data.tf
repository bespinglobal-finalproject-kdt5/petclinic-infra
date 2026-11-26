data "aws_cloudfront_origin_request_policy" "api" {
  name = "Managed-AllViewerExceptHostHeader"
}

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_lb" "eks" {
  count = local.use_vpc_origin ? 1 : 0
  arn   = var.eks_alb_arn

  lifecycle {
    postcondition {
      condition     = self.internal && self.load_balancer_type == "application" && self.vpc_id == var.vpc_id
      error_message = "The EKS origin must be an internal Application Load Balancer in the Seoul service VPC."
    }
  }
}

data "aws_ec2_managed_prefix_list" "cloudfront_origin" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}
