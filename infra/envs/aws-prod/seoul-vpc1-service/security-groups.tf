# 비공개 RDS에 붙이는 보안 그룹
resource "aws_security_group" "rds" {
  name        = "db-asg"
  description = "db-asg"
  vpc_id      = aws_vpc.service.id
}

# 임시 EC2에 붙이는 보안 그룹
resource "aws_security_group" "test_db_ec2" {
  name        = "test-db-ec2"
  description = "test-db-ec2"
  vpc_id      = aws_vpc.service.id
}

# 임시 EC2가 HTTP 패키지 저장소에 접속하도록 허용한다.
resource "aws_vpc_security_group_egress_rule" "test_ec2_http" {
  security_group_id = aws_security_group.test_db_ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# 임시 EC2가 NAT를 통해 SSM과 HTTPS 저장소에 연결하도록 허용한다.
resource "aws_vpc_security_group_egress_rule" "test_ec2_https" {
  security_group_id = aws_security_group.test_db_ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# 임시 EC2가 RDS로 PostgreSQL 연결을 시작하도록 허용한다.
resource "aws_vpc_security_group_egress_rule" "test_ec2_to_rds" {
  security_group_id            = aws_security_group.test_db_ec2.id
  referenced_security_group_id = aws_security_group.rds.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# RDS가 임시 EC2에서 오는 PostgreSQL 연결을 받도록 허용한다.
resource "aws_vpc_security_group_ingress_rule" "rds_from_test_ec2" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.test_db_ec2.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
