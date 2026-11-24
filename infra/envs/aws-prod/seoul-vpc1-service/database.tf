resource "aws_db_instance" "petclinic" {
  identifier     = "petclinic-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.small"

  db_name             = "petclinic"
  username            = "petclinic"
  password_wo         = var.db_master_password
  password_wo_version = 1

  db_subnet_group_name   = aws_db_subnet_group.petclinic.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # 인터넷에서 직접 접속할 수 없도록 설정

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  skip_final_snapshot       = false
  final_snapshot_identifier = "petclinic-was-db-poc-final"
}
