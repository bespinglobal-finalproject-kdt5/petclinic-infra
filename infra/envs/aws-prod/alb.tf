locals {
  edge_tags = { project = "petclinic", environment = "prod", component = "network" }
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# Fixed responses need no outbound connections or target groups.
resource "aws_security_group" "origin" {
  name_prefix = "petclinic-origin-"
  description = "Internal ALB for CloudFront VPC origin"
  vpc_id      = module.network.service_vpc_id
  tags        = merge(local.edge_tags, { Name = "petclinic-prod-origin-alb-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "cloudfront_http" {
  security_group_id = aws_security_group.origin.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  tags              = merge(local.edge_tags, { Name = "petclinic-prod-cloudfront-http-ingress" })
}

resource "aws_lb" "origin" {
  internal           = true
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  subnets            = module.network.app_subnet_ids
  security_groups    = [aws_security_group.origin.id]
  tags               = merge(local.edge_tags, { Name = "petclinic-prod-origin-alb" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.origin.arn
  port              = 80
  protocol          = "HTTP"
  tags              = merge(local.edge_tags, { Name = "petclinic-prod-origin-http-listener" })

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "404"
      message_body = "Not found"
    }
  }
}

resource "aws_lb_listener_rule" "health" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  tags         = merge(local.edge_tags, { Name = "petclinic-prod-origin-health-rule" })

  condition {
    path_pattern { values = ["/health"] }
  }
  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      message_body = "OK"
    }
  }
}
