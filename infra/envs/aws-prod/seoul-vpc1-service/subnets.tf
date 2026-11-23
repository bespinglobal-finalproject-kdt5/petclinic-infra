locals {
  service_subnets = {
    app_1    = { cidr = "10.10.0.0/24", az_index = 0, table = "app", component = "app" }
    app_2    = { cidr = "10.10.1.0/24", az_index = 1, table = "app", component = "app" }
    public_1 = { cidr = "10.10.2.0/27", az_index = 0, table = "public", component = "network" }
    public_2 = { cidr = "10.10.2.32/27", az_index = 1, table = "public", component = "network" }
    db_1     = { cidr = "10.10.2.64/27", az_index = 0, table = "private", component = "database" }
    db_2     = { cidr = "10.10.2.96/27", az_index = 1, table = "private", component = "database" }
  }
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

resource "aws_route_table_association" "service" {
  for_each       = local.service_subnets
  subnet_id      = aws_subnet.service[each.key].id
  route_table_id = local.service_route_table_ids[each.value.table]
}
