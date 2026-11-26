locals {
  use_vpc_origin = var.eks_alb_arn != null
  alb_dns_name   = one(data.aws_lb.eks[*].dns_name)
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

resource "aws_cloudfront_vpc_origin" "eks" {
  count = length(data.aws_lb.eks)

  vpc_origin_endpoint_config {
    name                   = "petclinic-prod-eks-alb"
    arn                    = var.eks_alb_arn
    http_port              = 80
    https_port             = 443 # Endpoint schema requires this even for http-only.
    origin_protocol_policy = "http-only"
    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
  tags = merge(local.edge_tags, { Name = "petclinic-prod-eks-vpc-origin" })
}
