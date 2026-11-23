output "instance_id" {
  value = aws_instance.build.id
}

output "security_group_id" {
  value = aws_security_group.build.id
}
