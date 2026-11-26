# Pin the Ubuntu release used by both hosts.
data "aws_ami" "ubuntu" {
  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20261120"]
  }
}

module "server" {
  source               = "./server"
  ubuntu_ami_id        = data.aws_ami.ubuntu.id
  vpc_id               = aws_vpc.management.id
  build_subnet_id      = aws_route_table_association.management_public.subnet_id
  management_subnet_id = aws_route_table_association.management.subnet_id
}

# The management resources retain their labels in the combined server module.
moved {
  from = module.management_server
  to   = module.server
}

moved {
  from = module.build_server.aws_security_group.build
  to   = module.server.aws_security_group.build
}

moved {
  from = module.build_server.aws_iam_role.build
  to   = module.server.aws_iam_role.build
}

moved {
  from = module.build_server.aws_iam_role_policy_attachment.ssm
  to   = module.server.aws_iam_role_policy_attachment.build_ssm
}

moved {
  from = module.build_server.aws_iam_instance_profile.build
  to   = module.server.aws_iam_instance_profile.build
}

moved {
  from = module.build_server.aws_instance.build
  to   = module.server.aws_instance.build
}

moved {
  from = module.build_server.aws_eip.build
  to   = module.server.aws_eip.build
}
