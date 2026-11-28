variable "domain" {
  type = string
}

variable "certificate_region" {
  description = "ACM region for the CloudFront viewer certificate."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "cloudfront_enabled" {
  description = "Serve traffic through the distribution using the configured internal ALB."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = !var.cloudfront_enabled || var.eks_alb_arn != null
    error_message = "Set eks_alb_arn before enabling the CloudFront distribution."
  }
}

variable "eks_alb_arn" {
  description = "ARN of the EKS-managed internal ALB used to provision the CloudFront VPC origin."
  type        = string
  default     = null
}
