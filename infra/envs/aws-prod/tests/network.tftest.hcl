mock_provider "aws" {
  source = "./tests/mocks"
}

run "network_topology" {
  command = plan
  module {
    source = "../../modules/aws-network"
  }
  variables {
    availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
    environment        = "prod"
  }

  assert {
    condition = (
      aws_vpc.service.cidr_block == "10.10.0.0/22" && aws_vpc.management.cidr_block == "10.20.0.0/24" &&
      aws_vpc.service.enable_dns_support && aws_vpc.service.enable_dns_hostnames &&
      aws_subnet.management.cidr_block == "10.20.0.0/27" && aws_subnet.management.availability_zone == var.availability_zones[0] &&
      aws_subnet.management.vpc_id == aws_vpc.management.id && !aws_subnet.management.map_public_ip_on_launch
    )
    error_message = "Unexpected VPC CIDRs or management subnet placement."
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
      aws_route_table.service_app.vpc_id == aws_vpc.service.id && one(aws_route_table.service_app.route).cidr_block == "0.0.0.0/0" &&
      one(aws_route_table.service_app.route).nat_gateway_id == aws_nat_gateway.public_1.id &&
      aws_route_table.service_private.vpc_id == aws_vpc.service.id && length(aws_route_table.service_private.route) == 0 &&
      aws_route_table.management.vpc_id == aws_vpc.management.id && length(aws_route_table.management.route) == 0 &&
      aws_route_table_association.management.route_table_id == aws_route_table.management.id &&
      aws_route_table_association.management.subnet_id == aws_subnet.management.id
    )
    error_message = "Public and app defaults must target the IGW and NAT respectively; DB and management tables must remain local-only."
  }
  assert {
    condition = alltrue([for tags in concat(
      [for s in aws_subnet.service : s.tags],
      [aws_vpc.service.tags, aws_vpc.management.tags, aws_internet_gateway.service.tags, aws_subnet.management.tags,
        aws_eip.app_nat.tags, aws_nat_gateway.public_1.tags, aws_route_table.service_app.tags,
      aws_route_table.service_public.tags, aws_route_table.service_private.tags, aws_route_table.management.tags]
    ) : tags.project == "petclinic" && tags.environment == "prod" && contains(["app", "database", "network", "management"], tags.component)])
    error_message = "All taggable resources need the common tags."
  }
  assert {
    condition = (
      output.service_vpc_id == aws_vpc.service.id && output.management_vpc_id == aws_vpc.management.id &&
      output.management_subnet_id == aws_subnet.management.id &&
      output.app_subnet_ids == [aws_subnet.service["app_1"].id, aws_subnet.service["app_2"].id] &&
      output.db_subnet_ids == [aws_subnet.service["db_1"].id, aws_subnet.service["db_2"].id] &&
      output.public_subnet_ids == [aws_subnet.service["public_1"].id, aws_subnet.service["public_2"].id]
    )
    error_message = "Output IDs must select the correct resources in operator AZ order."
  }
}
