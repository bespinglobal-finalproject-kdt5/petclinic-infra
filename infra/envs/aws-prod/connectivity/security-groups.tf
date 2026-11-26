resource "aws_vpc_security_group_ingress_rule" "rds_from_management" {
  security_group_id = var.rds_security_group_id
  cidr_ipv4         = var.management_host_cidr
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
  security_group_id = var.management_security_group_id
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
  security_group_id = var.eks_security_group_id
  description       = "Private API from the existing management EC2 over peering"
  cidr_ipv4         = var.management_host_cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_eks" {
  security_group_id            = var.rds_security_group_id
  referenced_security_group_id = var.eks_security_group_id
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

resource "aws_vpc_security_group_ingress_rule" "rds_from_azure_dr_nat" {
  security_group_id = var.rds_security_group_id
  cidr_ipv4         = "${var.azure_dr_nat_public_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432

  tags = {
    project     = "petclinic"
    environment = "prod"
    component   = "database"
    Name        = "petclinic-prod-rds-from-azure-dr-nat"
  }
}
