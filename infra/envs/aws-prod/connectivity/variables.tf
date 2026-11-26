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
