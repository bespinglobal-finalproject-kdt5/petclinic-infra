mock_provider "aws" {
  source = "./tests/mocks"
}

run "retained_osaka_network_and_ssm" {
  command = plan
  module { source = "./osaka-monitoring" }

  assert {
    condition = (
      aws_vpc.osaka.cidr_block == "10.40.0.0/16" &&
      aws_subnet.osaka.cidr_block == "10.40.0.0/27" &&
      aws_subnet.osaka.vpc_id == aws_vpc.osaka.id &&
      output.vpc_id == aws_vpc.osaka.id && output.subnet_id == aws_subnet.osaka.id
    )
    error_message = "Keep the original Osaka VPC and subnet."
  }

  assert {
    condition = (
      aws_iam_role.ssm.name == "petclinic-prod-osaka-ssm" &&
      aws_iam_instance_profile.ssm.role == aws_iam_role.ssm.name &&
      aws_iam_role_policy.ssm.name == "session-manager-agent" &&
      contains(one(jsondecode(aws_iam_role_policy.ssm.policy).Statement).Action, "ssmmessages:OpenDataChannel")
    )
    error_message = "Keep the EC2 role, Session Manager permissions and instance profile for future hosts."
  }
}
