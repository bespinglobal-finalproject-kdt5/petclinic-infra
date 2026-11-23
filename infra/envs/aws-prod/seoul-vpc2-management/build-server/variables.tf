variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "Management VPC public subnet with its internet route ready."
  type        = string
}
