# 앱용 자격 증명을 저장할 Secret을 만든다.
resource "aws_secretsmanager_secret" "petclinic_app" {
  name = "petclinic/was-db-poc/app"
}

# Proxy가 사용할 사용자명과 비밀번호를 JSON으로 저장한다.
resource "aws_secretsmanager_secret_version" "petclinic_app" {
  secret_id = aws_secretsmanager_secret.petclinic_app.id

  # secret_string_wo = jsonencode({
  #   username = "petclinic_app"
  #   password = var.db_app_password
  # })

  #secret_string_wo_version = 1
}
