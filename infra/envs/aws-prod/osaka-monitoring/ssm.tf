# EC2 agent permissions only; operator StartSession and EKS access are separate.
resource "aws_iam_role" "ssm" {
  name = "petclinic-prod-osaka-ssm"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = { Name = "petclinic-prod-osaka-ssm" }
}

resource "aws_iam_role_policy" "ssm" {
  name = "session-manager-agent"
  role = aws_iam_role.ssm.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:UpdateInstanceInformation",
        "ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "ssm" {
  name = aws_iam_role.ssm.name
  role = aws_iam_role.ssm.name
  tags = { Name = "petclinic-prod-osaka-ssm" }
}
