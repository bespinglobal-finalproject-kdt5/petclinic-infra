mock_provider "aws" {
  source = "./tests/mocks"
}

run "build_host" {
  command = plan
  module { source = "./seoul-vpc2-management/build-server" }
  override_resource {
    target          = aws_instance.build
    override_during = plan
    values          = { id = "i-00000000000000001" }
  }
  variables {
    ubuntu_ami_id = "ami-00000000000000001"
    vpc_id        = "vpc-00000000000000001"
    subnet_id     = "subnet-00000000000000003"
  }

  assert {
    condition = (
      aws_instance.build.instance_type == "m7i.large" && aws_instance.build.subnet_id == var.subnet_id &&
      aws_instance.build.associate_public_ip_address && aws_instance.build.metadata_options[0].http_tokens == "required" &&
      aws_instance.build.root_block_device[0].volume_type == "gp3" && aws_instance.build.root_block_device[0].volume_size == 50 &&
      aws_instance.build.root_block_device[0].encrypted && aws_instance.build.iam_instance_profile == aws_iam_instance_profile.build.name &&
      aws_iam_role_policy_attachment.ssm.role == aws_iam_instance_profile.build.role &&
      aws_iam_role_policy_attachment.ssm.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    )
    error_message = "Build EC2 must meet the instance, disk and SSM specification."
  }

  assert {
    condition = (
      aws_security_group.build.vpc_id == var.vpc_id && length(aws_security_group.build.ingress) == 1 &&
      one(aws_security_group.build.ingress).protocol == "tcp" &&
      one(aws_security_group.build.ingress).from_port == 22 && one(aws_security_group.build.ingress).to_port == 22 &&
      one(aws_security_group.build.ingress).cidr_blocks == tolist(["0.0.0.0/0"]) &&
      toset([for rule in aws_security_group.build.egress : rule.to_port]) == toset([80, 443]) &&
      alltrue([for rule in aws_security_group.build.egress : rule.from_port == rule.to_port && rule.protocol == "tcp" && contains(rule.cidr_blocks, "0.0.0.0/0")])
    )
    error_message = "The build security group must allow inbound IPv4 SSH and outbound HTTP and HTTPS."
  }

  assert {
    condition     = aws_eip.build.domain == "vpc" && aws_eip.build.instance == aws_instance.build.id
    error_message = "The Elastic IP must be associated with the build instance."
  }
}
