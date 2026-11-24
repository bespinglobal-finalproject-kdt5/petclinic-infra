# 앱용 Secret을 사용하고 TLS를 요구하는 PostgreSQL Proxy
resource "aws_db_proxy" "petclinic" {
  name                   = "petclinic-was-db-poc-proxy"
  engine_family          = "POSTGRESQL"
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [aws_security_group.rds_proxy.id]

  # 서로 다른 가용 영역의 DB 서브넷에 Proxy를 배치
  vpc_subnet_ids = [
    aws_subnet.service["db_1"].id,
    aws_subnet.service["db_2"].id,
  ]

  # 클라이언트는 petclinic_app의 DB 비밀번호로 연결
  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.petclinic_app.arn
  }


  # # Secret 값과 읽기 권한이 준비된 뒤 Proxy를 생성
  # depends_on = [
  #   aws_iam_role_policy.rds_proxy_read_app_secret,
  #   aws_secretsmanager_secret_version.db_master_password,
  # ]
}

# AWS가 만든 기본 타깃 그룹에 기존 RDS를 등록
resource "aws_db_proxy_target" "petclinic" {
  db_proxy_name          = aws_db_proxy.petclinic.name
  target_group_name      = "default"
  db_instance_identifier = aws_db_instance.petclinic.identifier
}
