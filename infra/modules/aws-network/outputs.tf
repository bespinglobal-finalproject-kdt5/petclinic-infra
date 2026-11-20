output "service_vpc_id" {
  value = aws_vpc.service.id
}

output "management_vpc_id" {
  value = aws_vpc.management.id
}

output "app_subnet_ids" {
  description = "App subnet IDs in availability_zones order."
  value       = [aws_subnet.service["app_1"].id, aws_subnet.service["app_2"].id]
}

output "db_subnet_ids" {
  description = "DB subnet IDs in availability_zones order."
  value       = [aws_subnet.service["db_1"].id, aws_subnet.service["db_2"].id]
}

output "public_subnet_ids" {
  description = "Public subnet IDs in availability_zones order."
  value       = [aws_subnet.service["public_1"].id, aws_subnet.service["public_2"].id]
}

output "management_subnet_id" {
  value = aws_subnet.management.id
}
