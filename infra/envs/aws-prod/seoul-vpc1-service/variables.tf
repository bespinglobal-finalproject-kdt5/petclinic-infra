variable "availability_zones" {
  description = "Two distinct operator-confirmed standard AWS AZ names in the provider region, in subnet order."
  type        = list(string)
  nullable    = false
  validation {
    condition = (
      length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2 &&
      alltrue([for az in var.availability_zones : can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+[a-z]$", az))])
    )
    error_message = "Supply exactly two distinct standard AWS availability-zone names."
  }
}

variable "environment" {
  description = "Petclinic environment tag."
  type        = string
  nullable    = false
  validation {
    condition     = contains(["prod", "azure_dr"], var.environment)
    error_message = "Environment must be prod or azure_dr."
  }
}

# 부모와 하위 모듈의 variables.tf에 각각 선언
variable "db_master_password" {
  type      = string
  sensitive = true        # 테라폼 출력에서 값 가림
  default   = "123456789" # 하드코딩시킴
}

variable "azure_dr_nat_public_ip" {
  description = "Static IPv4 address of the Azure DR NAT gateway."
  type        = string
}
