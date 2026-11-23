mock_provider "aws" {
  source = "./tests/mocks"
}

run "network_topology" {
  command = plan
  module {
    source = "./network"
  }
  variables {
    availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
    environment        = "prod"
  }

  assert {
    condition = (
      aws_vpc.service.cidr_block == "10.10.0.0/22" && aws_vpc.management[0].cidr_block == "10.20.0.0/24" &&
      aws_vpc.service.enable_dns_support && aws_vpc.service.enable_dns_hostnames &&
      aws_subnet.management[0].cidr_block == "10.20.0.0/27" && aws_subnet.management[0].availability_zone == var.availability_zones[0] &&
      aws_subnet.management[0].vpc_id == aws_vpc.management[0].id && !aws_subnet.management[0].map_public_ip_on_launch
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
      aws_route_table.management[0].vpc_id == aws_vpc.management[0].id && length(aws_route_table.management[0].route) == 0 &&
      aws_route_table_association.management[0].route_table_id == aws_route_table.management[0].id &&
      aws_route_table_association.management[0].subnet_id == aws_subnet.management[0].id
    )
    error_message = "Public and app defaults must target the IGW and NAT respectively; DB and management tables must remain local-only."
  }
  assert {
    condition = alltrue([for tags in concat(
      [for s in aws_subnet.service : s.tags],
      [aws_vpc.service.tags, aws_vpc.management[0].tags, aws_internet_gateway.service.tags, aws_subnet.management[0].tags,
        aws_eip.app_nat.tags, aws_nat_gateway.public_1.tags, aws_route_table.service_app.tags,
      aws_route_table.service_public.tags, aws_route_table.service_private.tags, aws_route_table.management[0].tags]
    ) : tags.project == "petclinic" && tags.environment == "prod" && startswith(tags.Name, "petclinic-prod-") && contains(["app", "database", "network", "management"], tags.component)])
    error_message = "All taggable resources need the common tags and a production Name."
  }
  assert {
    condition = (
      output.service_vpc_id == aws_vpc.service.id && output.management_vpc_id == aws_vpc.management[0].id &&
      output.management_subnet_id == aws_subnet.management[0].id &&
      output.app_subnet_ids == [aws_subnet.service["app_1"].id, aws_subnet.service["app_2"].id] &&
      output.db_subnet_ids == [aws_subnet.service["db_1"].id, aws_subnet.service["db_2"].id] &&
      output.public_subnet_ids == [aws_subnet.service["public_1"].id, aws_subnet.service["public_2"].id]
    )
    error_message = "Output IDs must select the correct resources in operator AZ order."
  }
}

run "peered_seoul_app_routes" {
  command = plan
  module { source = "./network" }
  variables {
    availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
    environment        = "prod"
    observe_peer       = { id = "pcx-0123456789abcdef0", subnet_cidr = "10.40.0.0/27" }
  }
  assert {
    condition = (
      output.app_subnet_cidrs == toset(["10.10.0.0/24", "10.10.1.0/24"]) && length(aws_route_table.service_app.route) == 2 &&
      one([for r in aws_route_table.service_app.route : r.vpc_peering_connection_id if r.cidr_block == var.observe_peer.subnet_cidr]) == var.observe_peer.id &&
      one([for r in aws_route_table.service_app.route : r.nat_gateway_id if r.cidr_block == "0.0.0.0/0"]) == aws_nat_gateway.public_1.id &&
      length(aws_route_table.service_private.route) == 0 && length(aws_route_table.management[0].route) == 0 &&
      one(aws_route_table.service_public.route).gateway_id == aws_internet_gateway.service.id
    )
    error_message = "Only app traffic to Osaka may use the peer. Keep the default NAT and isolate other tiers."
  }
}
