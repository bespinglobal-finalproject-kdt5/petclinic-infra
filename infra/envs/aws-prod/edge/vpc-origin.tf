data "aws_lb" "eks" {
  count = var.eks_alb_arn == null ? 0 : 1
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
    arn                    = data.aws_lb.eks[count.index].arn
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
