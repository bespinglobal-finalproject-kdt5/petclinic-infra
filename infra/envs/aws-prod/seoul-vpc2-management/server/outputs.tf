output "build_instance_id" {
  value = aws_instance.build.id
}

output "management_instance_id" {
  value = aws_instance.management.id
}

output "management_role_name" {
  value = aws_iam_role.management.name
}

output "management_role_arn" {
  value = aws_iam_role.management.arn
}

output "management_security_group_id" {
  value = aws_security_group.management.id
}

output "management_private_ip" {
  value = aws_instance.management.private_ip
}
