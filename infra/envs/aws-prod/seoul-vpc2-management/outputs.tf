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
  value = module.server.build_instance_id
}

output "management_instance_id" {
  value = module.server.management_instance_id
}

output "management_role_name" {
  value = module.server.management_role_name
}
output "management_role_arn" {
  value = module.server.management_role_arn
}
output "management_security_group_id" {
  value = module.server.management_security_group_id
}
output "management_private_ip" {
  value = module.server.management_private_ip
}
output "management_nat_public_ip" {
  value = aws_eip.management_nat.public_ip
}
