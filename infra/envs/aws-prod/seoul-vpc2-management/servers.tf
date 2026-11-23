# Pin the Ubuntu release used by both hosts.
data "aws_ami" "ubuntu" {
  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20261120"]
  }
}

module "build_server" {
  source        = "./build-server"
  ubuntu_ami_id = data.aws_ami.ubuntu.id
  vpc_id        = aws_vpc.management.id
  subnet_id     = aws_route_table_association.management_public.subnet_id
}

module "management_server" {
  source                  = "./management-server"
  ubuntu_ami_id           = data.aws_ami.ubuntu.id
  vpc_id                  = aws_vpc.management.id
  subnet_id               = aws_route_table_association.management.subnet_id
  build_security_group_id = module.build_server.security_group_id
}
