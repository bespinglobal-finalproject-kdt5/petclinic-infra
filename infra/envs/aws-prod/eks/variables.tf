variable "name" {
  type     = string
  nullable = false
}

variable "tags" {
  type     = map(string)
  nullable = false
}

variable "subnet_ids" {
  description = "Private application subnets for the cluster and managed nodes."
  type        = list(string)
  nullable    = false
}

variable "kubernetes_version" {
  description = "Kubernetes minor version shared by the control plane and managed nodes."
  type        = string
  nullable    = false
}

variable "ami_type" {
  type     = string
  nullable = false
}

variable "node_ami_release" {
  description = "EKS node AMI release. A null value uses the EKS default on creation."
  type        = string
}

variable "vpc_cni_version" {
  description = "EKS build of vpc-cni. A null value uses the EKS default on creation."
  type        = string
}
