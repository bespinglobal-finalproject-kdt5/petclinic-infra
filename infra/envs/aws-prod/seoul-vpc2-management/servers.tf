module "server" {
  source               = "./server"
  ubuntu_ami_id        = data.aws_ami.ubuntu.id
  vpc_id               = aws_vpc.management.id
  build_subnet_id      = aws_route_table_association.management_public.subnet_id
  management_subnet_id = aws_route_table_association.management.subnet_id
}
