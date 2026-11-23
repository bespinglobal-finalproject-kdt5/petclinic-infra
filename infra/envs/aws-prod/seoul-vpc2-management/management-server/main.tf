terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

locals {
  name = "petclinic-prod-management"
  tags = { project = "petclinic", environment = "prod", component = "management" }
}

resource "aws_iam_role" "management" {
  name = "${local.name}-ssm"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = merge(local.tags, { Name = "${local.name}-ssm" })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.management.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "management" {
  name = aws_iam_role.management.name
  role = aws_iam_role.management.name
  tags = merge(local.tags, { Name = "${local.name}-ssm" })
}

resource "aws_instance" "management" {
  ami                         = var.ubuntu_ami_id
  instance_type               = "t3.small"
  subnet_id                   = var.subnet_id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.management.id]
  iam_instance_profile        = aws_iam_instance_profile.management.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
    tags                  = merge(local.tags, { Name = "${local.name}-root" })
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(local.tags, { Name = "${local.name}-server" })
  depends_on = [
    aws_iam_role_policy_attachment.ssm,
    aws_vpc_security_group_egress_rule.ssm_https,
    aws_vpc_endpoint.ssm,
  ]
}
