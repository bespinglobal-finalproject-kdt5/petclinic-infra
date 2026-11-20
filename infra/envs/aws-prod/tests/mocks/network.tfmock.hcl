# Generate per-instance IDs at plan time so assertions can distinguish wiring.
mock_resource "aws_vpc" {
  override_during = plan
}

mock_resource "aws_subnet" {
  override_during = plan
}

mock_resource "aws_internet_gateway" {
  override_during = plan
}

mock_resource "aws_eip" {
  override_during = plan
}

mock_resource "aws_nat_gateway" {
  override_during = plan
}

mock_resource "aws_route_table" {
  override_during = plan
}
