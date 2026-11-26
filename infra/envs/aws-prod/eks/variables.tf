variable "aws_region" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "service_vpc_id" {
  type = string
}

variable "app_subnet_ids" {
  description = "Private app subnets in the production AZ order."
  type        = list(string)
}

variable "cluster_admins" {
  description = "Principal ARNs keyed by stable ARNs known before IAM role creation."
  type        = map(string)
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "node_instance_type" {
  type = string
}

variable "node_scaling" {
  type = object({ min = number, desired = number, max = number })
}

variable "node_release_version" {
  type = string
}

variable "addon_versions" {
  type = map(string)
}
