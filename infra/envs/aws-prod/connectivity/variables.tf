variable "management_vpc_id" {
  type = string
}

variable "service_vpc_id" {
  type = string
}

variable "management_security_group_id" {
  type = string
}

variable "rds_security_group_id" {
  type = string
}

variable "eks_security_group_id" {
  type = string
}

variable "management_host_cidr" {
  type = string
}

variable "azure_dr_nat_public_ip" {
  description = "Static IPv4 address used by the Azure DR NAT gateway for outbound connections."
  type        = string
}
