# Azure에서 인터넷으로 송신할 때 사용하는 NAT 공인 IP.
output "public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.flexible_server.fqdn
}

output "vm_public_ip" {
  value = azurerm_public_ip.vm.ip_address
}

output "vm_ssh" {
  value = "ssh ${var.vm_admin_username}@${azurerm_public_ip.vm.ip_address}"
}
