mock_provider "aws" {
  source = "./tests/mocks"
}

run "management_network" {
  command = plan
  module { source = "./seoul-vpc2-management" }
  variables {
    availability_zone = "ap-northeast-2a"
    service_peer_id   = "pcx-00000000000000002"
  }

  assert {
    condition = (
      aws_vpc.management.enable_dns_support && aws_vpc.management.enable_dns_hostnames &&
      aws_vpc.management.cidr_block == "10.20.0.0/24" && output.management_vpc_id == aws_vpc.management.id &&
      aws_subnet.management.cidr_block == "10.20.0.0/27" && aws_subnet.management_public.cidr_block == "10.20.0.32/27" &&
      alltrue([for subnet in [aws_subnet.management, aws_subnet.management_public] :
      subnet.vpc_id == aws_vpc.management.id && subnet.availability_zone == var.availability_zone && !subnet.map_public_ip_on_launch]) &&
      output.management_subnet_id == aws_subnet.management.id && output.management_public_subnet_id == aws_subnet.management_public.id
    )
    error_message = "Keep the private management and public build subnets in Seoul VPC 2."
  }

  assert {
    condition = (
      aws_route_table.management.vpc_id == aws_vpc.management.id && length(aws_route_table.management.route) == 2 &&
      one([for route in aws_route_table.management.route : route.nat_gateway_id if route.cidr_block == "0.0.0.0/0"]) == aws_nat_gateway.management.id &&
      one([for route in aws_route_table.management.route : route.vpc_peering_connection_id if route.cidr_block == "10.10.0.0/22"]) == var.service_peer_id &&
      aws_nat_gateway.management.subnet_id == aws_subnet.management_public.id &&
      aws_nat_gateway.management.allocation_id == aws_eip.management_nat.id &&
      aws_route_table.management_public.vpc_id == aws_vpc.management.id && aws_internet_gateway.management.vpc_id == aws_vpc.management.id &&
      one(aws_route_table.management_public.route).cidr_block == "0.0.0.0/0" &&
      one(aws_route_table.management_public.route).gateway_id == aws_internet_gateway.management.id &&
      aws_route_table_association.management.route_table_id == aws_route_table.management.id &&
      aws_route_table_association.management.subnet_id == aws_subnet.management.id &&
      aws_route_table_association.management_public.route_table_id == aws_route_table.management_public.id &&
      aws_route_table_association.management_public.subnet_id == aws_subnet.management_public.id
    )
    error_message = "Check management egress through the public-subnet NAT, the service peer route, and the build subnet's direct IGW route."
  }

  assert {
    condition = alltrue([for tags in [
      aws_vpc.management.tags, aws_subnet.management.tags, aws_subnet.management_public.tags,
      aws_route_table.management.tags, aws_route_table.management_public.tags, aws_internet_gateway.management.tags
    ] : tags.project == "petclinic" && tags.environment == "prod" && tags.component == "management" && startswith(tags.Name, "petclinic-prod-management-")])
    error_message = "Management network resources must keep their production tags."
  }
}
