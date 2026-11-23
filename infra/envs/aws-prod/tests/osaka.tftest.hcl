mock_provider "aws" {
  source = "./tests/mocks"
}

run "retained_osaka_network_and_ssm" {
  command = plan
  module { source = "./osaka-monitoring" }

  variables {
    seoul_vpc_id    = "vpc-00000000000000001"
    seoul_region    = "ap-northeast-2"
    seoul_app_cidrs = ["10.10.0.0/24", "10.10.1.0/24"]
  }

  assert {
    condition = (
      aws_vpc_peering_connection.seoul_osaka.region == var.seoul_region &&
      aws_vpc_peering_connection.seoul_osaka.vpc_id == var.seoul_vpc_id &&
      aws_vpc_peering_connection.seoul_osaka.peer_vpc_id == aws_vpc.osaka.id &&
      aws_vpc_peering_connection.seoul_osaka.peer_region == "ap-northeast-3" &&
      !aws_vpc_peering_connection.seoul_osaka.auto_accept && aws_vpc_peering_connection_accepter.osaka.auto_accept &&
      aws_vpc_peering_connection_accepter.osaka.vpc_peering_connection_id == aws_vpc_peering_connection.seoul_osaka.id &&
      toset([for route in aws_route_table.osaka.route : route.cidr_block if route.vpc_peering_connection_id == output.peering_id]) == var.seoul_app_cidrs &&
      length(aws_route_table.osaka.route) == length(var.seoul_app_cidrs) &&
      aws_route_table_association.osaka.route_table_id == aws_route_table.osaka.id && aws_route_table_association.osaka.subnet_id == aws_subnet.osaka.id
    )
    error_message = "Osaka must accept the Seoul service peer and route only the two app subnets back through it."
  }

  assert {
    condition = (
      aws_vpc.osaka.cidr_block == "10.40.0.0/16" &&
      aws_subnet.osaka.cidr_block == "10.40.0.0/27" &&
      aws_subnet.osaka.vpc_id == aws_vpc.osaka.id &&
      output.vpc_id == aws_vpc.osaka.id && output.subnet_id == aws_subnet.osaka.id
    )
    error_message = "Keep the original Osaka VPC and subnet."
  }

  assert {
    condition = (
      aws_iam_role.ssm.name == "petclinic-prod-osaka-ssm" &&
      aws_iam_instance_profile.ssm.role == aws_iam_role.ssm.name &&
      aws_iam_role_policy.ssm.name == "session-manager-agent" &&
      contains(one(jsondecode(aws_iam_role_policy.ssm.policy).Statement).Action, "ssmmessages:OpenDataChannel")
    )
    error_message = "Keep the EC2 role, Session Manager permissions and instance profile for future hosts."
  }
}
