# 이전 ALB의 리스너 규칙과 대상 그룹. 새 Ingress의 백엔드는 EKS에서 정의한다.
/*
# The EKS configuration registers targets for these two NodePort services.
locals {
  workloads = {
    web = { port = 30080, health = "/", priority = 100, paths = ["/*"] }
    api = { port = 30966, health = "/petclinic/actuator/health/readiness", priority = 20, paths = ["/petclinic/api", "/petclinic/api/*"] }
  }
  application_tags = { project = "petclinic", environment = "prod", component = "app" }
}

resource "aws_lb_target_group" "app" {
  for_each             = local.workloads
  name                 = "petclinic-prod-${each.key}"
  target_type          = "instance"
  port                 = each.value.port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
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
*/
