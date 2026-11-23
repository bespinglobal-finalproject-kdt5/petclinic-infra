# Inter-region peering: request in Seoul and accept in Osaka in the same account.
resource "aws_vpc_peering_connection" "seoul_osaka" {
  region      = var.seoul_region
  vpc_id      = var.seoul_vpc_id
  peer_vpc_id = aws_vpc.osaka.id
  peer_region = "ap-northeast-3"
  auto_accept = false
  tags        = { project = "petclinic", environment = "prod", component = "network", Name = "petclinic-prod-seoul-osaka-peer" }
}

resource "aws_vpc_peering_connection_accepter" "osaka" {
  vpc_peering_connection_id = aws_vpc_peering_connection.seoul_osaka.id
  auto_accept               = true
  tags                      = { Name = "petclinic-prod-osaka-seoul-peer" }
}

resource "aws_route_table" "osaka" {
  vpc_id = aws_vpc.osaka.id
  tags   = { Name = "osaka-observe-peer-rtb" }

  dynamic "route" {
    for_each = var.seoul_app_cidrs
    content {
      cidr_block                = route.value
      vpc_peering_connection_id = aws_vpc_peering_connection_accepter.osaka.id
    }
  }
}

resource "aws_route_table_association" "osaka" {
  subnet_id      = aws_subnet.osaka.id
  route_table_id = aws_route_table.osaka.id
}
