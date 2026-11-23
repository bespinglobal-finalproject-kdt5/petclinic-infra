locals {
  db_tags = { project = "petclinic", environment = "prod", component = "database" }
}

resource "aws_db_subnet_group" "petclinic" {
  name       = "petclinic-prod-postgres"
  subnet_ids = var.db_subnet_ids
  tags       = merge(local.db_tags, { Name = "petclinic-prod-postgres-subnets" })
}

resource "aws_security_group" "postgres" {
  name        = "petclinic-prod-postgres"
  description = "PostgreSQL from EKS application nodes only"
  vpc_id      = var.vpc_id
  tags        = merge(local.db_tags, { Name = "petclinic-prod-postgres-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "eks_postgres" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = var.cluster_security_group_id
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
