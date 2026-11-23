locals {
  db_tags = { project = "petclinic", environment = "prod", component = "database" }
}

resource "aws_db_subnet_group" "petclinic" {
  name       = "petclinic-prod-postgres"
  subnet_ids = module.network.db_subnet_ids
  tags       = merge(local.db_tags, { Name = "petclinic-prod-postgres-subnets" })
}

resource "aws_security_group" "postgres" {
  name        = "petclinic-prod-postgres"
  description = "PostgreSQL from EKS application nodes only"
  vpc_id      = module.network.service_vpc_id
  tags        = merge(local.db_tags, { Name = "petclinic-prod-postgres-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "eks_postgres" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = aws_eks_cluster.petclinic.vpc_config[0].cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  tags                         = merge(local.db_tags, { Name = "petclinic-prod-eks-postgres-ingress" })
}

resource "aws_db_instance" "petclinic" {
  identifier                  = "petclinic-prod-postgres"
  engine                      = "postgres"
  engine_version              = "16.15"
  instance_class              = "db.t4g.micro"
  db_name                     = "petclinic"
  username                    = "petclinic_admin"
  manage_master_user_password = true
  port                        = 5432
  allocated_storage           = 20
  storage_type                = "gp3"
  storage_encrypted           = true
  db_subnet_group_name        = aws_db_subnet_group.petclinic.name
  vpc_security_group_ids      = [aws_security_group.postgres.id]
  multi_az                    = true
  publicly_accessible         = false
  backup_retention_period     = 7
  deletion_protection         = true
  skip_final_snapshot         = false
  final_snapshot_identifier   = "petclinic-prod-postgres-final"
  copy_tags_to_snapshot       = true
  tags                        = merge(local.db_tags, { Name = "petclinic-prod-postgres" })
}

output "db_host" {
  description = "RDS DNS hostname (without port), required for TLS hostname validation."
  value       = aws_db_instance.petclinic.address
}

output "db_master_secret_arn" {
  description = "ARN only. Read AWSCURRENT outside Terraform during the controlled bootstrap."
  value       = aws_db_instance.petclinic.master_user_secret[0].secret_arn
}
