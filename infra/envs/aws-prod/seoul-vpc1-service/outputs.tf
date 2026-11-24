output "service_vpc_id" {
  value = aws_vpc.service.id
}

output "app_subnet_ids" {
  description = "App subnet IDs in availability_zones order."
  value       = [aws_subnet.service["app_1"].id, aws_subnet.service["app_2"].id]
  # Consumers (including CloudFront VPC origins) need the attached IGW and subnet routing ready.
  depends_on = [aws_route_table_association.service]
}

output "db_subnet_ids" {
  description = "DB subnet IDs in availability_zones order."
  value       = [aws_subnet.service["db_1"].id, aws_subnet.service["db_2"].id]
}

output "public_subnet_ids" {
  description = "Public subnet IDs in availability_zones order."
  value       = [aws_subnet.service["public_1"].id, aws_subnet.service["public_2"].id]
}

output "app_subnet_cidrs" {
  value = toset([for subnet in local.service_subnets : subnet.cidr if subnet.table == "app"])
}

output "test_db_ec2_instance_id" {
  value = aws_instance.test_db_ec2.id
}

output "database_connection" {
  description = "Connection metadata for the database operator and the REST deployment."
  value = {
    instance_address      = aws_db_instance.petclinic.address
    proxy_endpoint        = aws_db_proxy.petclinic.endpoint
    app_secret_arn        = aws_secretsmanager_secret.petclinic_app.arn
    bootstrap_instance_id = aws_instance.test_db_ec2.id
  }
}
