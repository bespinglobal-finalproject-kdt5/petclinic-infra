resource "aws_security_group" "azure_dr_nlb" {
  name        = "petclinic-nlb-pg-sg"
  description = "AWS, Azure"
  vpc_id      = aws_vpc.service.id
}

resource "aws_vpc_security_group_ingress_rule" "nlb_from_azure" {
  security_group_id = aws_security_group.azure_dr_nlb.id
  cidr_ipv4         = "${var.azure_dr_nat_public_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
}

resource "aws_vpc_security_group_egress_rule" "azure_dr_nlb" {
  security_group_id = aws_security_group.azure_dr_nlb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_nlb" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.azure_dr_nlb.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_lb" "azure_dr" {
  name                             = "AWS-Azure"
  load_balancer_type               = "network"
  internal                         = false
  enable_cross_zone_load_balancing = true
  security_groups                  = [aws_security_group.azure_dr_nlb.id]
  subnets                          = [aws_subnet.service["public_1"].id, aws_subnet.service["public_2"].id]
  depends_on                       = [aws_internet_gateway.service]
}

resource "aws_lb_target_group" "azure_dr" {
  name        = "AWS-Azure"
  vpc_id      = aws_vpc.service.id
  target_type = "ip"
  port        = 5432
  protocol    = "TCP"

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "azure_dr" {
  load_balancer_arn = aws_lb.azure_dr.arn
  port              = 5432
  protocol          = "TCP"

  default_action {
    # ELB returns both forms for this single weighted target group.
    type             = "forward"
    target_group_arn = aws_lb_target_group.azure_dr.arn
    forward {
      target_group {
        arn    = aws_lb_target_group.azure_dr.arn
        weight = 1
      }
    }
  }
}

locals {
  # A backup or monitoring update can keep the existing writer location.
  rds_writer_az = aws_db_instance.petclinic.availability_zone
}

# The NLB registers a private IP. Select the DB interface in the current writer's AZ.
data "aws_network_interface" "rds_writer" {
  filter {
    name   = "description"
    values = ["RDSNetworkInterface"]
  }
  filter {
    name   = "group-id"
    values = [aws_security_group.rds.id]
  }
  filter {
    name   = "subnet-id"
    values = [aws_subnet.service["db_1"].id, aws_subnet.service["db_2"].id]
  }
  filter {
    name   = "availability-zone"
    values = [local.rds_writer_az]
  }
}

resource "aws_lb_target_group_attachment" "rds_writer" {
  target_group_arn  = aws_lb_target_group.azure_dr.arn
  target_id         = data.aws_network_interface.rds_writer.private_ip
  port              = 5432
  availability_zone = data.aws_network_interface.rds_writer.availability_zone

  lifecycle { create_before_destroy = true }
}
