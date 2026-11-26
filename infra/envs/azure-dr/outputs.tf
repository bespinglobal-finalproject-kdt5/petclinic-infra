# RDS 보안 그룹에 /32 로 넣을 Azure 출구. 서버 FQDN 과 다르다.
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
