locals {
  internal_alb_name = "petclinic-prod-internal-alb"
  internal_alb_tags = { Name = local.internal_alb_name, project = "petclinic", environment = "prod", component = "network" }
}

resource "aws_security_group" "internal_alb" {
  name        = local.internal_alb_name
  description = "Seoul internal ALB HTTPS listener"
  vpc_id      = module.seoul_vpc1.service_vpc_id
  tags        = local.internal_alb_tags
}

resource "aws_vpc_security_group_ingress_rule" "internal_alb_https" {
  security_group_id = aws_security_group.internal_alb.id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_origin.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS from the CloudFront origin-facing prefix list"
}

resource "aws_lb" "internal" {
  name               = local.internal_alb_name
  load_balancer_type = "application"
  internal           = true
  subnets            = module.seoul_vpc1.app_subnet_ids
  security_groups    = [aws_security_group.internal_alb.id]
  tags               = local.internal_alb_tags
}

resource "aws_lb_listener" "internal_https" {
  load_balancer_arn = aws_lb.internal.arn
  protocol          = "HTTPS"
  port              = 443
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = module.edge.alb_certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "503"
      message_body = "Service unavailable"
    }
  }
}
