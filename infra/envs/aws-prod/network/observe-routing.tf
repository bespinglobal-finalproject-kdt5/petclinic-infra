variable "observe_peer" {
  description = "Optional private route from the two Seoul app subnets to the Osaka observation subnet."
  type        = object({ id = string, subnet_cidr = string })
  default     = null
}

output "app_subnet_cidrs" {
  value = toset([for subnet in local.service_subnets : subnet.cidr if subnet.table == "app"])
}
