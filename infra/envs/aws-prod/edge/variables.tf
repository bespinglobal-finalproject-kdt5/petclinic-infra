variable "domain" {
  type = string
}

variable "certificate_region" {
  description = "ACM region for the CloudFront viewer certificate."
  type        = string
}

variable "public_zone_id" {
  description = "Existing Route 53 public zone for the domain."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "app_subnet_ids" {
  type = list(string)
}

variable "cluster_security_group_id" {
  type = string
}

variable "node_autoscaling_group_name" {
  type = string
}
