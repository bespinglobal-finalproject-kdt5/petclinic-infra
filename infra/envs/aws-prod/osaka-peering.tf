# Inter-region peering: request in Seoul and accept in Osaka in the same account.
resource "aws_vpc_peering_connection" "seoul_osaka" {
  vpc_id      = module.network.service_vpc_id
  peer_vpc_id = module.osaka_observe.vpc_id
  peer_region = "ap-northeast-3"
  auto_accept = false
  tags        = { project = "petclinic", environment = "prod", component = "network", Name = "petclinic-prod-seoul-osaka-peer" }
}

resource "aws_vpc_peering_connection_accepter" "osaka" {
  provider                  = aws.osaka
  vpc_peering_connection_id = aws_vpc_peering_connection.seoul_osaka.id
  auto_accept               = true
  tags                      = { Name = "petclinic-prod-osaka-seoul-peer" }
}
