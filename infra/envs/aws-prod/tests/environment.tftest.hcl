mock_provider "aws" {
  source = "./tests/mocks"
}

mock_provider "aws" {
  alias  = "us_east_1"
  source = "./tests/mocks"
}

mock_provider "aws" {
  alias  = "osaka"
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
}

run "seoul_management_outputs" {
  command = plan
  assert {
    condition = (
      output.service_vpc_id == module.network.service_vpc_id && output.management_vpc_id == module.network.management_vpc_id &&
      output.management_subnet_id == module.network.management_subnet_id &&
      output.app_subnet_ids == module.network.app_subnet_ids && output.db_subnet_ids == module.network.db_subnet_ids &&
      output.public_subnet_ids == module.network.public_subnet_ids
    )
    error_message = "The production root must expose all six module outputs without reordering."
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

run "osaka_is_observability_only" {
  command = plan
  assert {
    condition = (
      output.osaka_observe.vpc_id == module.osaka_observe.vpc_id && output.osaka_observe.subnet_id == module.osaka_observe.subnet_id &&
      output.management_vpc_id != null && output.management_subnet_id != null &&
      output.management_vpc_id != output.osaka_observe.vpc_id && output.management_subnet_id != output.osaka_observe.subnet_id
    )
    error_message = "Seoul management and Osaka monitoring must have independent VPC and subnet outputs."
  }
}
