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
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.aws_region))
    error_message = "Supply an AWS region name."
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
