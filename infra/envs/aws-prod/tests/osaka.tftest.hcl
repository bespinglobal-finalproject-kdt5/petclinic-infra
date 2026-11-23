mock_provider "aws" {
  source = "./tests/mocks"
}

run "observe_layout" {
  command = plan
  module { source = "../../modules/osaka-observe" }
  variables {
    my_ip           = "192.0.2.17"
    key_name        = "mock-key"
    seoul_app_cidrs = ["10.10.0.0/24", "10.10.1.0/24"]
    peering_id      = "pcx-0123456789abcdef0"
  }
  assert {
    condition = (
      aws_vpc.osaka.cidr_block == "10.40.0.0/16" && aws_subnet.osaka.cidr_block == "10.40.0.0/27" &&
      aws_instance.osaka.iam_instance_profile == aws_iam_instance_profile.ssm.name &&
      aws_subnet.osaka.vpc_id == aws_vpc.osaka.id && aws_subnet.osaka.map_public_ip_on_launch &&
      aws_instance.osaka.subnet_id == aws_subnet.osaka.id && aws_instance.osaka.associate_public_ip_address &&
      aws_instance.osaka.instance_type == "t3.medium" && aws_instance.osaka.root_block_device[0].encrypted &&
      aws_instance.osaka.root_block_device[0].volume_size == 30 && aws_instance.osaka.metadata_options[0].http_tokens == "required" &&
      aws_route_table_association.osaka.subnet_id == aws_subnet.osaka.id &&
      one([for r in aws_route_table.osaka.route : r.gateway_id if r.cidr_block == "0.0.0.0/0"]) == aws_internet_gateway.osaka.id &&
      toset([for r in aws_route_table.osaka.route : r.cidr_block if r.vpc_peering_connection_id == var.peering_id]) == var.seoul_app_cidrs
    )
    error_message = "The Osaka observation VM must use the specified public subnet, IGW, size, encrypted root and IMDSv2."
  }
  assert {
    condition = (
      length(aws_security_group.osaka.ingress) == 3 && toset([for r in aws_security_group.osaka.ingress : r.from_port]) == toset([22, 3000, 9090]) &&
      alltrue([for r in aws_security_group.osaka.ingress : r.protocol == "tcp" && r.from_port == r.to_port &&
      toset(r.cidr_blocks) == (r.from_port == 22 ? var.seoul_app_cidrs : toset(["192.0.2.17/32"]))])
    )
    error_message = "SSH must be private from Seoul app subnets only; dashboards must stay restricted to the operator /32."
  }
}
