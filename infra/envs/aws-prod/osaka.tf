# Provider scope is the region boundary: do not change the default Seoul provider.
provider "aws" {
  alias               = "osaka"
  region              = "ap-northeast-3"
  allowed_account_ids = [var.aws_account_id]
  default_tags {
    tags = { project = "petclinic", environment = "prod", component = "management" }
  }
}

variable "osaka_admin_ipv4" {
  description = "Trusted administrator IPv4 address, without CIDR. Supply privately; never commit the value."
  type        = string
  nullable    = false
  validation {
    condition     = can(cidrnetmask("${var.osaka_admin_ipv4}/32")) && var.osaka_admin_ipv4 != "0.0.0.0"
    error_message = "Supply one IPv4 host, not a network, IPv6 address, or wildcard."
  }
}
variable "osaka_key_name" {
  type        = string
  description = "Existing EC2 key pair in Osaka. Keep its private key outside Terraform."
  default     = "osaka-key"
}
variable "retire_seoul_management_vpc" {
  type        = bool
  description = "Osaka is the active management network. Setting false would recreate the retired Seoul management network."
  default     = true
}
module "osaka_observe" {
  source          = "../../modules/osaka-observe"
  providers       = { aws = aws.osaka }
  my_ip           = var.osaka_admin_ipv4
  key_name        = var.osaka_key_name
  seoul_app_cidrs = module.network.app_subnet_cidrs
  peering_id      = aws_vpc_peering_connection_accepter.osaka.id
}
output "osaka_observe" {
  description = "Osaka candidate/end-state management network. EC2 public IP may change after stop/start."
  value = {
    vpc_id      = module.osaka_observe.vpc_id
    subnet_id   = module.osaka_observe.subnet_id
    instance_id = module.osaka_observe.instance_id
    public_ip   = module.osaka_observe.public_ip
    private_ip  = module.osaka_observe.private_ip
  }
}
