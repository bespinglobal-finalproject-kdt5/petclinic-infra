locals {
  use_vpc_origin = var.eks_alb_arn != null
  alb_dns_name   = one(data.aws_lb.eks[*].dns_name)
}

resource "aws_cloudfront_vpc_origin" "eks" {
  count = length(data.aws_lb.eks)

  vpc_origin_endpoint_config {
    name                   = "petclinic-prod-eks-alb"
    arn                    = var.eks_alb_arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "https-only"
    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
  tags = merge(local.edge_tags, { Name = "petclinic-prod-eks-vpc-origin" })
}
