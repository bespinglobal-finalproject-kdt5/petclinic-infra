output "management_vpc_id" {
  value = aws_vpc.management.id
}

output "management_subnet_id" {
  value = aws_subnet.management.id
}

output "management_public_subnet_id" {
  value      = aws_subnet.management_public.id
  depends_on = [aws_route_table_association.management_public]
}

output "build_instance_id" {
  value = module.build_server.instance_id
}
