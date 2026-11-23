output "instance_id" {
  value = aws_instance.management.id
}

output "role_name" { value = aws_iam_role.management.name }
output "role_arn" { value = aws_iam_role.management.arn }
output "security_group_id" { value = aws_security_group.management.id }
output "private_ip" { value = aws_instance.management.private_ip }