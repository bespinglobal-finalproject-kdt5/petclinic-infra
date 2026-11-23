# 관제 서버 한 대. Prom·Loki·Tempo·Grafana·Alertmanager를 여기에 올린다.
resource "aws_instance" "osaka" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.osaka.id
  vpc_security_group_ids      = [aws_security_group.osaka.id]
  associate_public_ip_address = true
  key_name                    = data.aws_key_pair.operator.key_name
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  depends_on                  = [aws_iam_role_policy.ssm, aws_route_table_association.osaka]

  # Canonical Ubuntu Server includes the SSM agent as a snap; ensure it is enabled.
  user_data = <<-SH
    #!/bin/bash
    set -eu
    if ! snap list amazon-ssm-agent >/dev/null 2>&1; then
      snap install amazon-ssm-agent --classic
    fi
    snap start --enable amazon-ssm-agent
  SH
  metadata_options { http_tokens = "required" }

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
    tags        = { Name = "osaka-observe-root-ebs" }
  }

  tags = {
    Name = "osaka-observe"
  }
}
