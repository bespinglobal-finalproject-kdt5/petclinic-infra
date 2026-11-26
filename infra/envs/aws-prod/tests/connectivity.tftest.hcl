mock_provider "aws" {
  source = "./tests/mocks"
}

variables {
  management_vpc_id            = "vpc-00000000000000001"
  service_vpc_id               = "vpc-00000000000000002"
  management_security_group_id = "sg-00000000000000003"
  rds_security_group_id        = "sg-00000000000000002"
  eks_security_group_id        = "sg-00000000000000001"
  management_host_cidr         = "10.20.0.19/32"
}

run "seoul_peering_and_management_api" {
  command = plan
  module { source = "./connectivity" }

  assert {
    condition = (
      aws_vpc_peering_connection.management_service.vpc_id == var.management_vpc_id &&
      aws_vpc_peering_connection.management_service.peer_vpc_id == var.service_vpc_id &&
      aws_vpc_peering_connection.management_service.auto_accept &&
      output.peering_connection_id == aws_vpc_peering_connection.management_service.id &&
      aws_vpc_peering_connection_options.management_service.vpc_peering_connection_id == output.peering_connection_id &&
      one(aws_vpc_peering_connection_options.management_service.requester).allow_remote_vpc_dns_resolution &&
      one(aws_vpc_peering_connection_options.management_service.accepter).allow_remote_vpc_dns_resolution
    )
    error_message = "Both VPCs must use the same peering connection with DNS resolution in both directions."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.management_api.security_group_id == var.eks_security_group_id &&
      aws_vpc_security_group_ingress_rule.management_api.cidr_ipv4 == var.management_host_cidr &&
      aws_vpc_security_group_ingress_rule.management_api.ip_protocol == "tcp" &&
      aws_vpc_security_group_ingress_rule.management_api.from_port == 443 &&
      aws_vpc_security_group_ingress_rule.management_api.to_port == 443
    )
    error_message = "The private EKS API must allow TCP 443 from the management host."
  }
}

run "postgres_from_eks_and_management" {
  command = plan
  module { source = "./connectivity" }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.rds_from_eks.security_group_id == var.rds_security_group_id &&
      aws_vpc_security_group_ingress_rule.rds_from_eks.referenced_security_group_id == var.eks_security_group_id &&
      aws_vpc_security_group_ingress_rule.rds_from_management.security_group_id == var.rds_security_group_id &&
      aws_vpc_security_group_ingress_rule.rds_from_management.cidr_ipv4 == var.management_host_cidr &&
      aws_vpc_security_group_egress_rule.management_to_rds.security_group_id == var.management_security_group_id &&
      aws_vpc_security_group_egress_rule.management_to_rds.cidr_ipv4 == "10.10.2.64/26" &&
      alltrue([for rule in [
        aws_vpc_security_group_ingress_rule.rds_from_eks,
        aws_vpc_security_group_ingress_rule.rds_from_management,
        aws_vpc_security_group_egress_rule.management_to_rds
      ] : rule.ip_protocol == "tcp" && rule.from_port == 5432 && rule.to_port == 5432])
    )
    error_message = "Allow PostgreSQL from the EKS cluster security group and from the management host to both DB subnets."
  }
}
