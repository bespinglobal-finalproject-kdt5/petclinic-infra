mock_provider "aws" {
  source = "./tests/mocks"
}

run "private_session_manager_host" {
  command = plan
  module { source = "./seoul-vpc2-management/management-server" }
  variables {
    vpc_id                  = "vpc-00000000000000001"
    subnet_id               = "subnet-00000000000000001"
    ubuntu_ami_id           = "ami-00000000000000001"
    build_security_group_id = "sg-00000000000000003"
  }

  override_resource {
    target          = aws_security_group.management
    override_during = plan
    values          = { id = "sg-00000000000000001" }
  }

  override_resource {
    target          = aws_security_group.endpoints
    override_during = plan
    values          = { id = "sg-00000000000000002" }
  }

  assert {
    condition = (
      aws_instance.management.ami == var.ubuntu_ami_id && aws_instance.management.instance_type == "t3.small" &&
      aws_instance.management.subnet_id == var.subnet_id && !aws_instance.management.associate_public_ip_address &&
      aws_instance.management.vpc_security_group_ids == toset([aws_security_group.management.id]) &&
      aws_instance.management.root_block_device[0].volume_type == "gp3" &&
      aws_instance.management.root_block_device[0].volume_size == 30 && aws_instance.management.root_block_device[0].encrypted &&
      aws_instance.management.metadata_options[0].http_tokens == "required" &&
      aws_instance.management.iam_instance_profile == aws_iam_instance_profile.management.name &&
      aws_iam_instance_profile.management.role == aws_iam_role_policy_attachment.ssm.role &&
      aws_iam_role_policy_attachment.ssm.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    )
    error_message = "The management EC2 must be private, match the specified hardware and use its own SSM profile."
  }

  assert {
    condition = (
      toset(keys(aws_vpc_endpoint.ssm)) == toset(["ssm", "ssmmessages"]) &&
      alltrue([for name, ep in aws_vpc_endpoint.ssm :
        ep.service_name == "com.amazonaws.ap-northeast-2.${name}" && ep.vpc_id == var.vpc_id &&
        ep.vpc_endpoint_type == "Interface" && ep.private_dns_enabled && ep.subnet_ids == toset([var.subnet_id]) &&
        ep.security_group_ids == toset([aws_security_group.endpoints.id])
      ])
    )
    error_message = "Both Seoul SSM interfaces must use private DNS and the private management subnet."
  }

  assert {
    condition = (
      aws_vpc_security_group_egress_rule.ssm_https.security_group_id == aws_security_group.management.id &&
      aws_vpc_security_group_egress_rule.ssm_https.referenced_security_group_id == aws_security_group.endpoints.id &&
      aws_vpc_security_group_egress_rule.ssm_https.ip_protocol == "tcp" &&
      aws_vpc_security_group_egress_rule.ssm_https.from_port == 443 && aws_vpc_security_group_egress_rule.ssm_https.to_port == 443 &&
      one(aws_security_group.endpoints.ingress).protocol == "tcp" && one(aws_security_group.endpoints.ingress).from_port == 443 &&
      one(aws_security_group.endpoints.ingress).to_port == 443 &&
      one(aws_security_group.endpoints.ingress).security_groups == toset([aws_security_group.management.id, var.build_security_group_id])
    )
    error_message = "Both management and existing build hosts must reach the private SSM endpoints over HTTPS."
  }
}
