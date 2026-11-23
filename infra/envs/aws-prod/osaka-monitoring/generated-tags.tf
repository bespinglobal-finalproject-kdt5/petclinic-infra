# Tag the automatically-created objects only. Do not adopt default routing, SG or ACL rules.
locals {
  generated_names = {
    primary_eni  = { id = aws_instance.osaka.primary_network_interface_id, name = "osaka-observe-primary-eni" }
    default_rtb  = { id = aws_vpc.osaka.default_route_table_id, name = "osaka-observe-default-rtb" }
    default_sg   = { id = aws_vpc.osaka.default_security_group_id, name = "osaka-observe-default-sg" }
    default_nacl = { id = aws_vpc.osaka.default_network_acl_id, name = "osaka-observe-default-nacl" }
  }
}

resource "aws_ec2_tag" "generated_name" {
  for_each    = local.generated_names
  resource_id = each.value.id
  key         = "Name"
  value       = each.value.name
}
