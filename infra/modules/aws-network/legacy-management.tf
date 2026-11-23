variable "retain_management" {
  type        = bool
  default     = true
  description = "Create the isolated Seoul management network. Enabled by the production root independently of monitoring."
}

# Preserve previous addresses in state. Turning on staged cutover must not replace a Seoul resource.
moved {
  from = aws_vpc.management
  to   = aws_vpc.management[0]
}
moved {
  from = aws_subnet.management
  to   = aws_subnet.management[0]
}
moved {
  from = aws_route_table.management
  to   = aws_route_table.management[0]
}
moved {
  from = aws_route_table_association.management
  to   = aws_route_table_association.management[0]
}
