variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "Private subnet shared by the management EC2 and SSM endpoints."
  type        = string
}

variable "ubuntu_ami_id" {
  type = string
}

variable "build_security_group_id" {
  description = "Build host that also resolves the VPC-wide private SSM names."
  type        = string
}
