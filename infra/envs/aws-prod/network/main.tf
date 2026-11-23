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
  service_subnets = {
    app_1    = { cidr = "10.10.0.0/24", az_index = 0, table = "app", component = "app" }
    app_2    = { cidr = "10.10.1.0/24", az_index = 1, table = "app", component = "app" }
    public_1 = { cidr = "10.10.2.0/27", az_index = 0, table = "public", component = "network" }
    public_2 = { cidr = "10.10.2.32/27", az_index = 1, table = "public", component = "network" }
    db_1     = { cidr = "10.10.2.64/27", az_index = 0, table = "private", component = "database" }
    db_2     = { cidr = "10.10.2.96/27", az_index = 1, table = "private", component = "database" }
  }
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

resource "aws_vpc" "management" {
  count      = var.retain_management ? 1 : 0
  cidr_block = "10.20.0.0/24"
  tags       = merge(local.tags, { component = "management", Name = "${local.name_prefix}-management-vpc" })
}

resource "aws_subnet" "service" {
  for_each                = local.service_subnets
  vpc_id                  = aws_vpc.service.id
  cidr_block              = each.value.cidr
  availability_zone       = var.availability_zones[each.value.az_index]
  map_public_ip_on_launch = false
  tags = merge(local.tags, {
    component = each.value.component
    Name      = "${local.name_prefix}-${split("_", each.key)[0]}-subnet-${local.az_labels[each.value.az_index]}"
  })
}

resource "aws_subnet" "management" {
  count                   = var.retain_management ? 1 : 0
  vpc_id                  = aws_vpc.management[0].id
  cidr_block              = "10.20.0.0/27"
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = false
  tags                    = merge(local.tags, { component = "management", Name = "${local.name_prefix}-management-subnet-${local.az_labels[0]}" })
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
  tags = merge(local.tags, { component = "network", Name = "${local.name_prefix}-app-rtb" })
}

# An explicit empty route set manages away non-local routes. AWS supplies local.
resource "aws_route_table" "service_private" {
  vpc_id = aws_vpc.service.id
  route  = []
  tags   = merge(local.tags, { component = "network", Name = "${local.name_prefix}-db-rtb" })
}

resource "aws_route_table" "management" {
  count  = var.retain_management ? 1 : 0
  vpc_id = aws_vpc.management[0].id
  route  = []
  tags   = merge(local.tags, { component = "management", Name = "${local.name_prefix}-management-rtb" })
}

resource "aws_route_table_association" "service" {
  for_each       = local.service_subnets
  subnet_id      = aws_subnet.service[each.key].id
  route_table_id = local.service_route_table_ids[each.value.table]
}

resource "aws_route_table_association" "management" {
  count          = var.retain_management ? 1 : 0
  subnet_id      = aws_subnet.management[0].id
  route_table_id = aws_route_table.management[0].id
}
