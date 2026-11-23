output "vpc_id" {
  value = aws_vpc.osaka.id
}

output "subnet_id" {
  value = aws_subnet.osaka.id
}

output "subnet_cidr" {
  value = aws_subnet.osaka.cidr_block
}
