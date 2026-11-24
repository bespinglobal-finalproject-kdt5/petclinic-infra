# 비공개 RDS에 붙이는 보안 그룹
resource "aws_security_group" "rds" {
  name        = "db-asg"
  description = "db-asg"
  vpc_id      = aws_vpc.service.id
}
