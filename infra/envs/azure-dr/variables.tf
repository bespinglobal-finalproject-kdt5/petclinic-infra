variable "azure_subscription_id" {
  type        = string
  description = "az account show --query id -o tsv 로 확인한 구독. tfvars 에만 둔다."
}

# 포털에 이미 있는 리소스 그룹. Terraform 이 이 그룹을 새로 만들지 않는다.
variable "resource_group_name" {
  type    = string
  default = "FINAL"
}

variable "zone" {
  type    = string
  default = "1"
}

# 노트북 공인 IP. /32 는 NSG 가 붙인다. checkip.amazonaws.com 결과만 넣는다.
variable "my_ip" {
  type = string
}

variable "vm_admin_username" {
  type    = string
  default = "azureuser"
}

# ssh-ed25519 또는 ssh-rsa 2048 이상 공개키 한 줄. tfvars 에만 둔다.
variable "vm_ssh_public_key" {
  type = string
}

variable "db_administrator_login" {
  type    = string
  default = "petclinic"
}

# 숫지만이면 Azure 가 거절할 수 있다. tfvars 에만 둔다.
variable "db_administrator_password" {
  type      = string
  sensitive = true
}
