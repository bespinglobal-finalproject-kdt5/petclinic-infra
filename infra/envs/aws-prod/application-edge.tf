# Existing internal ALB -> two NodePort Services. EC2 targets track the managed node ASG.
locals {
  workloads = {
    web = { port = 30080, health = "/", priority = 100, paths = ["/*"] }
    api = { port = 30966, health = "/petclinic/actuator/health/readiness", priority = 20, paths = ["/petclinic/api", "/petclinic/api/*"] }
  }
  application_tags = { project = "petclinic", environment = "prod", component = "app" }
}

resource "aws_ecr_repository" "petclinic" {
  for_each             = local.workloads
  name                 = "petclinic-prod/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = merge(local.application_tags, { Name = "petclinic-prod-${each.key}-ecr" })
}

resource "aws_lb_target_group" "app" {
  for_each             = local.workloads
  name                 = "petclinic-prod-${each.key}"
  target_type          = "instance"
  port                 = each.value.port
  protocol             = "HTTP"
  vpc_id               = module.network.service_vpc_id
  deregistration_delay = 30
  health_check {
    path                = each.value.health
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  tags = merge(local.application_tags, { Name = "petclinic-prod-${each.key}-tg" })
}

resource "aws_autoscaling_attachment" "app" {
  for_each               = local.workloads
  autoscaling_group_name = aws_eks_node_group.app.resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.app[each.key].arn
}

resource "aws_vpc_security_group_egress_rule" "alb_to_node" {
  for_each                     = local.workloads
  security_group_id            = aws_security_group.origin.id
  referenced_security_group_id = aws_eks_cluster.petclinic.vpc_config[0].cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  tags                         = merge(local.application_tags, { Name = "petclinic-prod-alb-to-${each.key}" })
}

resource "aws_vpc_security_group_ingress_rule" "node_from_alb" {
  for_each                     = local.workloads
  security_group_id            = aws_eks_cluster.petclinic.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.origin.id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  tags                         = merge(local.application_tags, { Name = "petclinic-prod-${each.key}-from-alb" })
}

resource "aws_lb_listener_rule" "app" {
  for_each     = local.workloads
  listener_arn = aws_lb_listener.http.arn
  priority     = each.value.priority
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[each.key].arn
  }
  condition {
    path_pattern { values = each.value.paths }
  }
  tags = merge(local.application_tags, { Name = "petclinic-prod-${each.key}-rule" })
}

data "aws_cloudfront_origin_request_policy" "api" {
  name = "Managed-AllViewerExceptHostHeader"
}

output "ecr_repository_urls" {
  value = { for k, repo in aws_ecr_repository.petclinic : k => repo.repository_url }
}
