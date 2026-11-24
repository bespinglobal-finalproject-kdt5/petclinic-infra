# rds 보안그룹
resource "aws_security_group" "rds" {
  name        = "db-asg"
  description = "db-asg"
  vpc_id      = aws_vpc.service.id
}

# RDS가 임시 EC2에서 오는 PostgreSQL 연결을 받도록 허용
resource "aws_vpc_security_group_ingress_rule" "rds_from_test_ec2" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.test_db_ec2.id # 출발지 보안 그룹 => cidr_ipv4 대신 씀
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}


# 임시 ec2 보안그룹
resource "aws_security_group" "test_db_ec2" {
  name        = "test-db-ec2"
  description = "test-db-ec2"
  vpc_id      = aws_vpc.service.id
}

# EC2에서 SSM과 패키지 저장소로 나가는 웹 연결을 허용
resource "aws_vpc_security_group_egress_rule" "test_ec2_http" {
  security_group_id = aws_security_group.test_db_ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# 임시 EC2의 SSM Agent가 NAT를 통해 AWS에 HTTPS로 연결하도록 허용
resource "aws_vpc_security_group_egress_rule" "test_ec2_https" {
  security_group_id = aws_security_group.test_db_ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# EC2에서 RDS로 나가는 PostgreSQL 연결을 허용
resource "aws_vpc_security_group_egress_rule" "test_ec2_to_rds" {
  security_group_id            = aws_security_group.test_db_ec2.id
  referenced_security_group_id = aws_security_group.rds.id # 목적지 보안 그룹
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# 서비스 VPC에 Proxy 전용 보안 그룹을 만든다.
resource "aws_security_group" "rds_proxy" {
  name        = "petclinic-was-db-poc-rds-proxy"
  description = "Security group for the PetClinic RDS Proxy"
  vpc_id      = aws_vpc.service.id
}

# 임시 EC2에서 Proxy로 나가는 연결을 허용한다.
resource "aws_vpc_security_group_egress_rule" "test_ec2_to_proxy" {
  security_group_id            = aws_security_group.test_db_ec2.id
  referenced_security_group_id = aws_security_group.rds_proxy.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# Proxy가 임시 EC2에서 오는 연결을 받도록 허용한다.
resource "aws_vpc_security_group_ingress_rule" "proxy_from_test_ec2" {
  security_group_id            = aws_security_group.rds_proxy.id
  referenced_security_group_id = aws_security_group.test_db_ec2.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# Proxy에서 RDS로 나가는 연결을 허용한다.
resource "aws_vpc_security_group_egress_rule" "proxy_to_rds" {
  security_group_id            = aws_security_group.rds_proxy.id
  referenced_security_group_id = aws_security_group.rds.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# RDS가 Proxy에서 오는 연결을 받도록 허용한다.
resource "aws_vpc_security_group_ingress_rule" "rds_from_proxy" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.rds_proxy.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
