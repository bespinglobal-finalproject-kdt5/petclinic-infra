resource "aws_security_group" "management" {
  name        = "${local.name}-server-sg"
  description = "Private management host using Session Manager"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "${local.name}-server-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.management.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_security_group" "endpoints" {
  name        = "${local.name}-ssm-endpoints-sg"
  description = "SSM endpoint HTTPS from the management and build hosts"
  vpc_id      = var.vpc_id
  egress      = []

  ingress {
    protocol        = "tcp"
    from_port       = 443
    to_port         = 443
    security_groups = [aws_security_group.management.id, var.build_security_group_id]
  }

  tags = merge(local.tags, { Name = "${local.name}-ssm-endpoints-sg" })
}

resource "aws_vpc_security_group_egress_rule" "ssm_https" {
  security_group_id            = aws_security_group.management.id
  referenced_security_group_id = aws_security_group.endpoints.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  tags                         = merge(local.tags, { Name = "${local.name}-to-ssm" })
}

resource "aws_vpc_endpoint" "ssm" {
  for_each            = toset(["ssm", "ssmmessages"])
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.ap-northeast-2.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [var.subnet_id]
  security_group_ids  = [aws_security_group.endpoints.id]
  tags                = merge(local.tags, { Name = "${local.name}-${each.key}-vpce" })
}
