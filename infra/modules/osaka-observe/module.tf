terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}
variable "key_name" { type = string }
variable "my_ip" { type = string }

data "aws_key_pair" "operator" { key_name = var.key_name }

output "vpc_id" { value = aws_vpc.osaka.id }
output "subnet_id" { value = aws_subnet.osaka.id }
output "instance_id" { value = aws_instance.osaka.id }

variable "seoul_app_cidrs" { type = set(string) }
variable "peering_id" { type = string }
output "subnet_cidr" { value = aws_subnet.osaka.cidr_block }
output "private_ip" { value = aws_instance.osaka.private_ip }
