variable "aws_account_id" {
  description = "Actual 12-digit target AWS account ID, confirmed by the operator."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Supply the target AWS account ID as a 12-digit string."
  }
}

variable "aws_region" {
  description = "Target AWS region confirmed by the operator."
  type        = string
  nullable    = false
  validation {
    condition     = var.aws_region == "ap-northeast-2"
    error_message = "The production origin must be in Seoul (ap-northeast-2)."
  }
}

variable "availability_zones" {
  description = "Two distinct standard AZ names confirmed for the target account and region. Order determines subnet placement; management uses the first."
  type        = list(string)
  nullable    = false
  validation {
    condition = (
      length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2 &&
      alltrue([for az in var.availability_zones : try(startswith(az, var.aws_region) && can(regex("^[a-z]$", trimprefix(az, var.aws_region))), false)])
    )
    error_message = "Supply exactly two distinct AZ names consisting of aws_region and one lowercase letter."
  }
}

variable "eks_alb_arn" {
  description = "ARN of the EKS-managed internal ALB. CloudFront stays disabled until this is set."
  type        = string
  default     = null
}

# 부모와 하위 모듈의 variables.tf에 각각 선언
variable "db_master_password" {
  type      = string
  sensitive = true
  default   = "123456789"
}

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
  description = "IAM principal ARNs for additional EKS administrators. The management EC2 role is added by the root."
  type        = set(string)
  nullable    = false
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
