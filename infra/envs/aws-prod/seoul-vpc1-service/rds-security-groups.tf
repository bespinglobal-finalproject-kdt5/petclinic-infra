# 운영 PostgreSQL RDS에 붙는 보안 그룹
resource "aws_security_group" "rds" {
  name        = "petclinic-prod-postgresql-rds-sg"
  description = "Security group for PetClinic PostgreSQL RDS"
  vpc_id      = aws_vpc.service.id

  # The old group must stay attached until RDS switches to the replacement.
  lifecycle { create_before_destroy = true }

  tags = {
    project     = "petclinic"
    environment = "prod"
    component   = "database"
    Name        = "petclinic-prod-postgresql-rds-sg"
  }
}

# EKS 보안 그룹이 확정나면 이 부분 수정
resource "aws_vpc_security_group_ingress_rule" "rds" {
  description = "Allow PostgreSQL from the PetClinic build server private IP"

  security_group_id = aws_security_group.rds.id
  # referenced_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  cidr_ipv4   = "10.20.0.58/32" # 접속할 EC2의 프라이빗 IPv4로 교체. 현재는 petclinic-prod-build-server ip
  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432

  tags = {
    project     = "petclinic"
    environment = "prod"
    component   = "database"
    Name        = "petclinic-prod-rds-ingress"
  }
}
