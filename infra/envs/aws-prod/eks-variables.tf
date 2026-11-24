variable "cluster_name" {
  type    = string
  default = "petclinic-prod-eks"
}
variable "kubernetes_version" {
  type    = string
  default = "1.36"
  validation {
    condition     = var.kubernetes_version == "1.36"
    error_message = "Review all component versions together before changing the baseline."
  }
}
variable "admin_principal_arns" {
  type    = set(string)
  default = ["arn:aws:iam::723926525504:user/KSM_final"]
}
variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}
variable "node_scaling" {
  type    = object({ min = number, desired = number, max = number })
  default = { min = 2, desired = 2, max = 4 }
  validation {
    condition     = var.node_scaling.min >= 1 && var.node_scaling.min <= var.node_scaling.desired && var.node_scaling.desired <= var.node_scaling.max && alltrue([for n in [var.node_scaling.min, var.node_scaling.desired, var.node_scaling.max] : floor(n) == n])
    error_message = "Use integers satisfying 1 <= min <= desired <= max."
  }
}
variable "node_release_version" {
  type = string
}
variable "addon_versions" {
  type = map(string)
  validation {
    condition     = alltrue([for name in ["vpc-cni", "coredns", "kube-proxy", "metrics-server"] : contains(keys(var.addon_versions), name)])
    error_message = "Supply all four compatible addon versions."
  }
}