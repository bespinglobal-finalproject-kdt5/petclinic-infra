output "vpc_id" {
  value = aws_vpc.osaka.id
}

output "subnet_id" {
  value = aws_subnet.osaka.id
}

output "subnet_cidr" {
  value = aws_subnet.osaka.cidr_block
}

output "peering_id" {
  description = "Accepted peering connection for the Seoul application route table."
  value       = aws_vpc_peering_connection_accepter.osaka.id
}

output "instance_id" {
  value = aws_instance.osaka.id
}

output "public_ip" {
  value = aws_instance.osaka.public_ip
}

output "private_ip" {
  value = aws_instance.osaka.private_ip
}
