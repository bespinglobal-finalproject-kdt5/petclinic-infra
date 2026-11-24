# 임시 EC2가 사용할 IAM 역할을 만든다.
resource "aws_iam_role" "test_db_ec2_ssm" {
  name = "test_db_ec2_ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# EC2의 SSM Agent가 Systems Manager에 등록하고 통신하도록 허용한다.
resource "aws_iam_role_policy_attachment" "test_db_ec2_ssm" {
  role       = aws_iam_role.test_db_ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM 역할을 임시 EC2에 붙일 수 있도록 인스턴스 프로파일에 담는다.
resource "aws_iam_instance_profile" "test_db_ec2" {
  name = "petclinic-was-db-poc-ec2"
  role = aws_iam_role.test_db_ec2_ssm.name
}

# RDS Proxy가 사용할 IAM 역할
resource "aws_iam_role" "rds_proxy" {
  name = "petclinic-was-db-poc-rds-proxy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# 위 역할이 petclinic_app용 Secret의 값만 읽도록 허용
resource "aws_iam_role_policy" "rds_proxy_read_app_secret" {
  name = "read-petclinic-app-secret"
  role = aws_iam_role.rds_proxy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.petclinic_app.arn
    }]
  })
}
