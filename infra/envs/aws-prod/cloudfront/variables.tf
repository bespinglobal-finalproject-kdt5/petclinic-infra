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

variable "eks_alb_arn" {
  description = "ARN of the EKS-managed internal ALB. CloudFront stays disabled until this is set."
  type        = string
  default     = null
}
