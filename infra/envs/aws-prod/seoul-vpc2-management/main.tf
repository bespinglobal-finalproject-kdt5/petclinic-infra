terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

locals {
  tags        = { project = "petclinic", environment = "prod", component = "management" }
  name_prefix = "petclinic-prod-management"
  az_label    = reverse(split("-", var.availability_zone))[0]
}

resource "aws_vpc" "management" {
  enable_dns_support   = true
  enable_dns_hostnames = true
  cidr_block           = "10.20.0.0/24"
  tags                 = merge(local.tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_subnet" "management" {
  vpc_id                  = aws_vpc.management.id
  cidr_block              = "10.20.0.0/27"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false
  tags                    = merge(local.tags, { Name = "${local.name_prefix}-subnet-${local.az_label}" })
}

resource "aws_route_table" "management" {
  vpc_id = aws_vpc.management.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.management.id
  }
  route {
    cidr_block                = "10.10.0.0/22"
    vpc_peering_connection_id = var.service_peer_id
  }
  tags = merge(local.tags, { Name = "${local.name_prefix}-rtb" })
}

resource "aws_route_table_association" "management" {
  subnet_id      = aws_subnet.management.id
  route_table_id = aws_route_table.management.id
}

resource "aws_subnet" "management_public" {
  vpc_id                  = aws_vpc.management.id
  cidr_block              = "10.20.0.32/27"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-subnet-${local.az_label}"
  })
}

resource "aws_internet_gateway" "management" {
  vpc_id = aws_vpc.management.id
  tags   = merge(local.tags, { Name = "${local.name_prefix}-igw" })
}

resource "aws_route_table" "management_public" {
  vpc_id = aws_vpc.management.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.management.id
  }

  tags = merge(local.tags, { Name = "${local.name_prefix}-public-rtb" })
}

resource "aws_route_table_association" "management_public" {
  subnet_id      = aws_subnet.management_public.id
  route_table_id = aws_route_table.management_public.id
}
