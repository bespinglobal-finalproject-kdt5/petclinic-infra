mock_provider "aws" {
  source = "./tests/mocks"
}

run "service_network" {
  command = plan
  module {
    source = "./seoul-vpc1-service"
  }
  variables {
    availability_zones         = ["ap-northeast-2a", "ap-northeast-2c"]
    environment                = "prod"
    db_app_password            = "mock-only-password"
    eks_node_security_group_id = "sg-00000000000000001"
    management_peer_id         = "pcx-00000000000000002"
    osaka_peer                 = { id = "pcx-00000000000000001", subnet_cidr = "10.40.0.0/27" }
  }

  override_resource {
    target          = aws_security_group.rds_proxy
    override_during = plan
    values          = { id = "sg-00000000000000002" }
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.proxy_from_eks.security_group_id == aws_security_group.rds_proxy.id &&
      aws_vpc_security_group_ingress_rule.proxy_from_eks.referenced_security_group_id == var.eks_node_security_group_id &&
      aws_vpc_security_group_ingress_rule.proxy_from_eks.ip_protocol == "tcp" &&
      aws_vpc_security_group_ingress_rule.proxy_from_eks.from_port == 5432 &&
      aws_vpc_security_group_ingress_rule.proxy_from_eks.to_port == 5432
    )
    error_message = "EKS nodes must reach the DB proxy on TCP 5432."
  }

  assert {
    condition     = aws_vpc.service.cidr_block == "10.10.0.0/22" && aws_vpc.service.enable_dns_support && aws_vpc.service.enable_dns_hostnames
    error_message = "Unexpected Seoul service VPC CIDR or DNS configuration."
  }
  assert {
    condition = { for k, s in aws_subnet.service : k => [s.cidr_block, s.availability_zone, s.tags.component] } == {
      app_1    = ["10.10.0.0/24", var.availability_zones[0], "app"]
      app_2    = ["10.10.1.0/24", var.availability_zones[1], "app"]
      public_1 = ["10.10.2.0/27", var.availability_zones[0], "network"]
      public_2 = ["10.10.2.32/27", var.availability_zones[1], "network"]
      db_1     = ["10.10.2.64/27", var.availability_zones[0], "database"]
      db_2     = ["10.10.2.96/27", var.availability_zones[1], "database"]
    }
    error_message = "Unexpected service subnet CIDR, AZ, or component."
  }
  assert {
    condition = alltrue([for k, s in aws_subnet.service : (
      s.vpc_id == aws_vpc.service.id && !s.map_public_ip_on_launch &&
      aws_route_table_association.service[k].subnet_id == s.id &&
      aws_route_table_association.service[k].route_table_id == {
        app    = aws_route_table.service_app.id
        public = aws_route_table.service_public.id
        db     = aws_route_table.service_private.id
      }[split("_", k)[0]]
    )])
    error_message = "Public, app, and DB subnets must each use their own tier's route table."
  }
  assert {
    condition = (
      aws_eip.app_nat.domain == "vpc" && aws_nat_gateway.public_1.allocation_id == aws_eip.app_nat.id &&
      aws_nat_gateway.public_1.subnet_id == aws_subnet.service["public_1"].id &&
      aws_nat_gateway.public_1.connectivity_type == "public" && aws_nat_gateway.public_1.availability_mode == "zonal"
    )
    error_message = "App egress requires a public zonal NAT in public_1 with its VPC EIP."
  }
  assert {
    condition = (
      aws_internet_gateway.service.vpc_id == aws_vpc.service.id && aws_route_table.service_public.vpc_id == aws_vpc.service.id &&
      one(aws_route_table.service_public.route).cidr_block == "0.0.0.0/0" &&
      one(aws_route_table.service_public.route).gateway_id == aws_internet_gateway.service.id &&
      aws_route_table.service_app.vpc_id == aws_vpc.service.id && length(aws_route_table.service_app.route) == 3 &&
      one([for route in aws_route_table.service_app.route : route.nat_gateway_id if route.cidr_block == "0.0.0.0/0"]) == aws_nat_gateway.public_1.id &&
      one([for route in aws_route_table.service_app.route : route.vpc_peering_connection_id if route.cidr_block == var.osaka_peer.subnet_cidr]) == var.osaka_peer.id &&
      one([for route in aws_route_table.service_app.route : route.vpc_peering_connection_id if route.cidr_block == "10.20.0.0/24"]) == var.management_peer_id &&
      aws_route_table.service_private.vpc_id == aws_vpc.service.id && length(aws_route_table.service_private.route) == 0
    )
    error_message = "Check the public IGW, app NAT, separate app routes to Osaka and management, and local-only DB table."
  }
  assert {
    condition = alltrue([for tags in concat(
      [for s in aws_subnet.service : s.tags],
      [aws_vpc.service.tags, aws_internet_gateway.service.tags,
        aws_eip.app_nat.tags, aws_nat_gateway.public_1.tags, aws_route_table.service_app.tags,
      aws_route_table.service_public.tags, aws_route_table.service_private.tags]
    ) : tags.project == "petclinic" && tags.environment == "prod" && startswith(tags.Name, "petclinic-prod-") && contains(["app", "database", "network", "management"], tags.component)])
    error_message = "All taggable resources need the common tags and a production Name."
  }
  assert {
    condition = (
      output.service_vpc_id == aws_vpc.service.id &&
      output.app_subnet_ids == [aws_subnet.service["app_1"].id, aws_subnet.service["app_2"].id] &&
      output.db_subnet_ids == [aws_subnet.service["db_1"].id, aws_subnet.service["db_2"].id] &&
      output.public_subnet_ids == [aws_subnet.service["public_1"].id, aws_subnet.service["public_2"].id]
    )
    error_message = "Output IDs must select the correct resources in operator AZ order."
  }

  assert {
    condition = (
      aws_db_instance.petclinic.engine == "postgres" &&
      !aws_db_instance.petclinic.publicly_accessible && aws_db_instance.petclinic.manage_master_user_password &&
      aws_db_instance.petclinic.db_subnet_group_name == aws_db_subnet_group.petclinic.name &&
      aws_db_subnet_group.petclinic.subnet_ids == toset(output.db_subnet_ids) &&
      aws_db_proxy.petclinic.vpc_subnet_ids == toset(output.db_subnet_ids) &&
      aws_db_proxy.petclinic.engine_family == "POSTGRESQL" && aws_db_proxy.petclinic.require_tls &&
      one(aws_db_proxy.petclinic.auth).auth_scheme == "SECRETS" &&
      aws_db_proxy_target.petclinic.db_proxy_name == aws_db_proxy.petclinic.name &&
      aws_db_proxy_target.petclinic.db_instance_identifier == aws_db_instance.petclinic.identifier
    )
    error_message = "Keep the PostgreSQL instance private and register it with the TLS proxy in the two DB subnets."
  }
}
