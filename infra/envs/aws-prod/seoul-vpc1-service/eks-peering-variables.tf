variable "management_peer_id" {
  type = string
}

variable "management_host_cidr" {
  type        = string
  description = "Private IPv4 /32 of the management server for database return traffic."
}
