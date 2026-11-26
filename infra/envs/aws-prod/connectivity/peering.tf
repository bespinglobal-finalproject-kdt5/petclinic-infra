resource "aws_vpc_peering_connection" "management_service" {
  vpc_id      = var.management_vpc_id
  peer_vpc_id = var.service_vpc_id
  auto_accept = true
  tags        = { Name = "petclinic-prod-management-service-peer" }
}

resource "aws_vpc_peering_connection_options" "management_service" {
  vpc_peering_connection_id = aws_vpc_peering_connection.management_service.id
  requester {
    allow_remote_vpc_dns_resolution = true
  }
  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}
