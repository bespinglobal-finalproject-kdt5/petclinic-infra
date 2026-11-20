mock_provider "aws" {
  source = "./tests/mocks"
}

# Synthetic account and Seoul AZs for mock plans only.
variables {
  aws_account_id     = "123456789012"
  aws_region         = "ap-northeast-2"
  availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
}

run "production_outputs" {
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
