locals {
  management_host_cidr = "${module.seoul_vpc2.management_private_ip}/32"
}

resource "aws_vpc_peering_connection" "management_service" {
  vpc_id      = module.seoul_vpc2.management_vpc_id
  peer_vpc_id = module.seoul_vpc1.service_vpc_id
  auto_accept = true
  tags        = { Name = "petclinic-prod-management-service-peer" }
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

resource "aws_vpc_security_group_ingress_rule" "rds_from_management" {
  security_group_id = module.seoul_vpc1.rds_security_group_id
  cidr_ipv4         = local.management_host_cidr
  description       = "PostgreSQL from the PetClinic management server"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432

  tags = {
    project     = "petclinic"
    environment = "prod"
    component   = "database"
    Name        = "petclinic-prod-rds-from-management"
  }
}

resource "aws_vpc_security_group_egress_rule" "management_to_rds" {
  security_group_id = module.seoul_vpc2.management_security_group_id
  cidr_ipv4         = "10.10.2.64/26"
  description       = "PostgreSQL to the two PetClinic RDS subnets"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432

  tags = {
    project     = "petclinic"
    environment = "prod"
    component   = "management"
    Name        = "petclinic-prod-management-to-rds"
  }
}

resource "aws_vpc_security_group_ingress_rule" "management_api" {
  security_group_id = module.eks.cluster_security_group_id
  description       = "Private API from the existing management EC2 over peering"
  cidr_ipv4         = local.management_host_cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_eks" {
  security_group_id            = module.seoul_vpc1.rds_security_group_id
  referenced_security_group_id = module.eks.cluster_security_group_id
  description                  = "Allow PostgreSQL from the PetClinic EKS cluster security group"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432

  tags = {
    project     = "petclinic"
    environment = "prod"
    component   = "database"
    Name        = "petclinic-prod-rds-from-eks"
  }
}
