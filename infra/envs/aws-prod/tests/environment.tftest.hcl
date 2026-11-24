mock_provider "aws" {
  source = "./tests/mocks"
}

mock_provider "tls" {}

override_resource {
  target          = module.seoul_vpc1.aws_vpc.service
  override_during = plan
  values          = { id = "vpc-00000000000000001" }
}

override_data {
  target = data.aws_vpc.service
  values = { enable_dns_support = true, enable_dns_hostnames = true }
}

override_data {
  target = data.aws_subnet.private["app_1"]
  values = { vpc_id = "vpc-00000000000000001", availability_zone = "ap-northeast-2a" }
}

override_data {
  target = data.aws_subnet.private["app_2"]
  values = { vpc_id = "vpc-00000000000000001", availability_zone = "ap-northeast-2c" }
}

mock_provider "aws" {
  alias  = "us_east_1"
  source = "./tests/mocks"
}

# Terraform mock providers cannot import an existing zone. Live plans verify its ID.
override_resource {
  target = module.edge.aws_route53_zone.delegated
  values = { zone_id = "ZMOCKPUBLIC" }
}

# Synthetic account and Seoul AZs for mock plans only.
variables {
  aws_account_id     = "123456789012"
  aws_region         = "ap-northeast-2"
  availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
  # Test fixtures only. Deployment versions are operator inputs.
  node_release_version = "1.36.0-20260101"
  admin_principal_arns = ["arn:aws:iam::123456789012:role/mock-eks-admin"]
  addon_versions = {
    vpc-cni        = "v1.0.0-eksbuild.1"
    coredns        = "v1.0.0-eksbuild.1"
    kube-proxy     = "v1.36.0-eksbuild.1"
    metrics-server = "v0.1.0-eksbuild.1"
  }
}

run "seoul_management_outputs" {
  command = plan
  assert {
    condition = (
      output.service_vpc_id == module.seoul_vpc1.service_vpc_id && output.management_vpc_id == module.seoul_vpc2.management_vpc_id &&
      output.management_subnet_id == module.seoul_vpc2.management_subnet_id &&
      output.app_subnet_ids == module.seoul_vpc1.app_subnet_ids && output.db_subnet_ids == module.seoul_vpc1.db_subnet_ids &&
      output.public_subnet_ids == module.seoul_vpc1.public_subnet_ids &&
      output.management_public_subnet_id == module.seoul_vpc2.management_public_subnet_id
    )
    error_message = "The production root must expose the service and management network outputs without reordering."
  }
}

run "plan_eks_before_subnet_ids_and_role_arn_are_assigned" {
  command = plan

  override_resource {
    target          = module.seoul_vpc1.aws_subnet.service
    override_during = apply
  }

  assert {
    condition = (
      toset(keys(data.aws_subnet.private)) == toset(["app_1", "app_2"]) &&
      aws_eks_cluster.this.vpc_config[0].endpoint_private_access && !aws_eks_cluster.this.vpc_config[0].endpoint_public_access &&
      toset(keys(aws_eks_access_entry.admin)) == setunion(var.admin_principal_arns, ["arn:aws:iam::123456789012:role/petclinic-prod-management-ssm"]) &&
      keys(aws_eks_access_entry.admin) == keys(aws_eks_access_policy_association.admin)
    )
    error_message = "A new environment must plan both app subnet lookups and the intended private-cluster access entries."
  }
}

run "reject_bad_account" {
  command = plan
  variables { aws_account_id = "12345678901x" }
  expect_failures = [var.aws_account_id]
}

run "reject_bad_region" {
  command = plan
  variables { aws_region = "Seoul" }
  expect_failures = [var.aws_region]
}

run "reject_duplicate_zones" {
  command = plan
  variables { availability_zones = ["ap-northeast-2a", "ap-northeast-2a"] }
  expect_failures = [var.availability_zones]
}

run "reject_single_zone" {
  command = plan
  variables { availability_zones = ["ap-northeast-2a"] }
  expect_failures = [var.availability_zones]
}

run "reject_wrong_region_zone" {
  command = plan
  variables { availability_zones = ["ap-northeast-2a", "ap-northeast-99c"] }
  expect_failures = [var.availability_zones]
}

run "public_edge" {
  command = plan
  assert {
    condition = (
      data.aws_route53_zone.public.name == "mission-critical.site" && !data.aws_route53_zone.public.private_zone &&
      output.public_url == module.edge.public_url && output.cloudfront_domain_name == module.edge.cloudfront_domain_name &&
      output.cloudfront_distribution_id == module.edge.cloudfront_distribution_id && output.internal_alb_dns_name == module.edge.internal_alb_dns_name
    )
    error_message = "The root must look up the existing public zone and publish the edge endpoints."
  }
}
