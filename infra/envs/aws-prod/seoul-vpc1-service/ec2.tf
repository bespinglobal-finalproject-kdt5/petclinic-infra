# test-ec2 생성
# 서울 리전에서 Ubuntu 24.04 x86_64 AMI ID를 조회한다.
data "aws_ssm_parameter" "ubuntu_2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "test_db_ec2" {
  # Ubuntu로 부팅하고, 이후 Docker 이미지 빌드도 할 수 있게 크기를 잡는다.
  ami           = data.aws_ssm_parameter.ubuntu_2404_ami.value
  instance_type = "t3.medium"

  # NAT 경로가 있는 앱 서브넷에 공인 IP 없이 배치한다.
  subnet_id                   = aws_subnet.service["app_1"].id
  associate_public_ip_address = false

  # 앞에서 만든 접속 규칙과 SSM용 인스턴스 프로파일을 연결한다.
  vpc_security_group_ids = [aws_security_group.test_db_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.test_db_ec2.name

  # 인스턴스 메타데이터에 접근할 때 IMDSv2 토큰을 요구한다.
  metadata_options {
    http_tokens = "required"
  }

  # Ubuntu와 Docker 이미지에 사용할 암호화된 디스크를 붙인다.
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "test-db-ec2"
  }

  # SSM 정책을 역할에 붙인 뒤 EC2를 생성한다.
  depends_on = [aws_iam_role_policy_attachment.test_db_ec2_ssm]
}
