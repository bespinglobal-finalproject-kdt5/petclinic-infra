output "db_host" {
  description = "RDS DNS hostname (without port), required for TLS hostname validation."
  value       = aws_db_instance.petclinic.address
}

output "db_master_secret_arn" {
  description = "ARN only. Read AWSCURRENT outside Terraform during the controlled bootstrap."
  value       = aws_db_instance.petclinic.master_user_secret[0].secret_arn
}
