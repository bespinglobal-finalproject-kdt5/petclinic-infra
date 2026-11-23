variable "seoul_region" {
  type = string
}

variable "seoul_vpc_id" {
  description = "Seoul service VPC requesting the peering connection."
  type        = string
}

variable "seoul_app_cidrs" {
  description = "Seoul app subnets reachable from the Osaka monitoring subnet."
  type        = set(string)
}
