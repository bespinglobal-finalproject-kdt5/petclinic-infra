resource "aws_eip" "management_nat" {
  domain = "vpc"
  tags   = merge(local.tags, { Name = "petclinic-prod-management-nat-eip" })
}
resource "aws_nat_gateway" "management" {
  allocation_id     = aws_eip.management_nat.id
  subnet_id         = aws_subnet.management_public.id
  connectivity_type = "public"
  tags              = merge(local.tags, { Name = "petclinic-prod-management-nat" })
  depends_on        = [aws_internet_gateway.management, aws_route_table_association.management_public]
}