# Keep Osaka separate from the Azure DR reservation (10.30.0.0/24).
resource "aws_vpc" "osaka" {
  cidr_block = "10.40.0.0/16"

  tags = {
    Name = "osaka-observe"
  }
}

# 방 하나. 서버 한 대라 /27 로 좁혔다. 쓸 수 있는 주소는 27개다.
resource "aws_subnet" "osaka" {
  vpc_id                  = aws_vpc.osaka.id
  cidr_block              = "10.40.0.0/27"
  map_public_ip_on_launch = true

  tags = {
    Name = "osaka-observe"
  }
}

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

# apply가 끝나면 브라우저에 넣을 공인 주소를 보여 준다.
output "public_ip" {
  value = aws_instance.osaka.public_ip
}

# 대문. 이게 없으면 서버가 밖으로 나가지도, 밖이 들어오지도 못한다.
resource "aws_internet_gateway" "osaka" {
  vpc_id = aws_vpc.osaka.id
  tags   = { Name = "osaka-observe-igw" }
}

# 약도. 우리 주소가 아닌 곳(0.0.0.0/0)은 대문으로 보낸다.
resource "aws_route_table" "osaka" {
  vpc_id = aws_vpc.osaka.id
  tags   = { Name = "osaka-observe-public-rtb" }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.osaka.id
  }
  dynamic "route" {
    for_each = var.seoul_app_cidrs
    content {
      cidr_block                = route.value
      vpc_peering_connection_id = var.peering_id
    }
  }
}

# 위 서브넷이 이 약도를 쓰게 붙인다.
resource "aws_route_table_association" "osaka" {
  subnet_id      = aws_subnet.osaka.id
  route_table_id = aws_route_table.osaka.id
}

# SSH uses private IPs across the peer; Grafana/Prometheus retain their separate operator /32.
resource "aws_security_group" "osaka" {
  vpc_id = aws_vpc.osaka.id
  tags   = { Name = "osaka-observe-sg" }

  # Terraform removes the default allow-all egress. Permit package/image downloads.
  dynamic "egress" {
    for_each = toset(["80", "443"])
    content {
      from_port   = tonumber(egress.value)
      to_port     = tonumber(egress.value)
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = sort(tolist(var.seoul_app_cidrs))
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"] # Grafana. 내 브라우저.
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"] # Prometheus 화면. 지금은 내 IP만.
  }
}
