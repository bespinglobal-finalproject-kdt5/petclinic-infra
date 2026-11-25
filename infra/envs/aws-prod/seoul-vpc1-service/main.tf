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
  service_route_table_ids = {
    app     = aws_route_table.service_app.id
    public  = aws_route_table.service_public.id
    private = aws_route_table.service_private.id
  }
  tags        = { project = "petclinic", environment = var.environment }
  name_prefix = "petclinic-${var.environment}"
  az_labels   = [for az in var.availability_zones : reverse(split("-", az))[0]]
}

resource "aws_vpc" "service" {
  cidr_block           = "10.10.0.0/22"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { component = "network", Name = "${local.name_prefix}-service-vpc" })
}

resource "aws_internet_gateway" "service" {
  vpc_id = aws_vpc.service.id
  tags   = merge(local.tags, { component = "network", Name = "${local.name_prefix}-service-igw" })
}

resource "aws_eip" "app_nat" {
  domain = "vpc"
  tags   = merge(local.tags, { component = "network", Name = "${local.name_prefix}-nat-eip" })
}

resource "aws_nat_gateway" "public_1" {
  allocation_id     = aws_eip.app_nat.id
  subnet_id         = aws_subnet.service["public_1"].id
  connectivity_type = "public"
  availability_mode = "zonal"
  tags              = merge(local.tags, { component = "network", Name = "${local.name_prefix}-nat-${local.az_labels[0]}" })

  depends_on = [aws_internet_gateway.service]
}

resource "aws_route_table" "service_public" {
  vpc_id = aws_vpc.service.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.service.id
  }
  tags = merge(local.tags, { component = "network", Name = "${local.name_prefix}-public-rtb" })
}

resource "aws_route_table" "service_app" {
  vpc_id = aws_vpc.service.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.public_1.id
  }
  route {
    cidr_block                = "10.20.0.0/24"
    vpc_peering_connection_id = var.management_peer_id
  }
  tags = merge(local.tags, { component = "network", Name = "${local.name_prefix}-app-rtb" })
}

resource "aws_route_table" "service_private" {
  vpc_id = aws_vpc.service.id
  route {
    cidr_block                = var.management_host_cidr
    vpc_peering_connection_id = var.management_peer_id
  }
  tags = merge(local.tags, { component = "network", Name = "${local.name_prefix}-db-rtb" })
}
