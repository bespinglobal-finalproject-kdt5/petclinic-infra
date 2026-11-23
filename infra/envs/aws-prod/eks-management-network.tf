resource "aws_vpc_peering_connection" "management_service" {
  vpc_id      = module.seoul_vpc2.management_vpc_id
  peer_vpc_id = module.seoul_vpc1.service_vpc_id
  auto_accept = true
  tags = { Name = "petclinic-prod-management-service-peer" }
}
resource "aws_vpc_peering_connection_options" "management_service" {
  vpc_peering_connection_id = aws_vpc_peering_connection.management_service.id
  requester {
    allow_remote_vpc_dns_resolution = true
  }
  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}
resource "aws_vpc_security_group_egress_rule" "management_https" {
  security_group_id = module.seoul_vpc2.management_security_group_id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "AWS API, EKS private API and HTTPS downloads"
}
resource "aws_vpc_security_group_egress_rule" "management_http" {
  security_group_id = module.seoul_vpc2.management_security_group_id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  description       = "Ubuntu package downloads and public ALB tests"
}