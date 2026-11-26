variable "vpc_id" {
  type = string
}

variable "ubuntu_ami_id" {
  type = string
}

variable "build_subnet_id" {
  description = "Public subnet for the build host."
  type        = string
}

variable "management_subnet_id" {
  description = "Private subnet for the management host and SSM endpoints."
  type        = string
}
