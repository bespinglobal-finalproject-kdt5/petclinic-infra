variable "my_ip" {
  description = "Administrator IPv4 address for the monitoring dashboards."
  type        = string
}

variable "key_name" {
  description = "Existing EC2 key pair in Osaka."
  type        = string
}

variable "seoul_region" {
  description = "Region in which the service VPC requests the peering connection."
  type        = string
}

variable "seoul_vpc_id" {
  type = string
}

variable "seoul_app_cidrs" {
  description = "Seoul application subnets routed over the peer."
  type        = set(string)
}
