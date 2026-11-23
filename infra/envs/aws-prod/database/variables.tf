variable "vpc_id" {
  type = string
}

variable "db_subnet_ids" {
  type = list(string)
}

variable "cluster_security_group_id" {
  description = "EKS security group allowed to reach PostgreSQL."
  type        = string
}
