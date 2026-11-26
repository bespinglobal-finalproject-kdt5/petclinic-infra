resource "aws_security_group" "build" {
  name        = "${local.build_name}-sg"
  description = "Session Manager build host with outbound web access"
  vpc_id      = var.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "egress" {
    for_each = [22, 80, 443, 5432]
    content {
      protocol    = "tcp"
      from_port   = egress.value
      to_port     = egress.value
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = merge(local.tags, { Name = "${local.build_name}-sg" })
}

resource "aws_iam_role" "build" {
  name = "${local.build_name}-ssm"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = merge(local.tags, { Name = "${local.build_name}-ssm" })
}

resource "aws_iam_role_policy_attachment" "build_ssm" {
  role       = aws_iam_role.build.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "build" {
  name = aws_iam_role.build.name
  role = aws_iam_role.build.name
  tags = merge(local.tags, { Name = "${local.build_name}-ssm" })
}

resource "aws_instance" "build" {
  ami                         = var.ubuntu_ami_id
  instance_type               = "m7i.large"
  subnet_id                   = var.build_subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.build.id]
  iam_instance_profile        = aws_iam_instance_profile.build.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50
    encrypted             = true
    delete_on_termination = true
    tags                  = merge(local.tags, { Name = "${local.build_name}-root" })
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags       = merge(local.tags, { Name = "${local.build_name}-server" })
  depends_on = [aws_iam_role_policy_attachment.build_ssm]
}

resource "aws_eip" "build" {
  domain   = "vpc"
  instance = aws_instance.build.id
}
