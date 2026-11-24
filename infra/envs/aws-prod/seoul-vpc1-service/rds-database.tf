resource "aws_db_instance" "petclinic" {
  # AWS 인스턴스 이름, DB 엔진, 인스턴스 크기
  identifier     = "petclinic-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.small"

  # 최초 데이터베이스와 관리자 계정
  db_name             = "petclinic"
  username            = "petclinic"
  password_wo         = var.db_master_password
  password_wo_version = 1

  # 서울 서비스 VPC의 프라이빗 DB 서브넷에 배치
  port                   = 5432
  db_subnet_group_name   = aws_db_subnet_group.petclinic.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # 공개 접근을 끈다.
  multi_az               = true

  # gp3 스토리지와 저장 암호화
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  # DB 삭제 시 최종 스냅샷을 생성
  skip_final_snapshot       = false
  final_snapshot_identifier = "petclinic-was-db-poc-final"

  tags = {
    project     = "petclinic"
    environment = "prod"
    component   = "database"
    Name        = "petclinic-prod-postgresql-rds"
  }
}
