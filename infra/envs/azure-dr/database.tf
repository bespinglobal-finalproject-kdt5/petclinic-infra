# Pet-DR-db-1 에 Flexible Server 를 위임한다.
# 공인 접속은 끈다. 노트북에서 바로 psql 하지 않는다. VM 에 SSH 한 뒤 사설 FQDN 으로 붙는다.

resource "azurerm_private_dns_zone" "pg" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "pg" {
  name                = "Services-VNet"
  private_dns_zone_id = azurerm_private_dns_zone.pg.id
  virtual_network_id  = azurerm_virtual_network.services_vnet.id
}

resource "azurerm_postgresql_flexible_server" "flexible_server" {
  name                = "sample-kc-dev-db-1"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  zone                = var.zone

  administrator_login    = var.db_administrator_login
  administrator_password = var.db_administrator_password

  sku_name     = "B_Standard_B2ats_v2"
  version      = "16"
  storage_mb   = 32768
  storage_tier = "P4"

  delegated_subnet_id           = azurerm_subnet.db.id
  private_dns_zone_id           = azurerm_private_dns_zone.pg.id
  public_network_access_enabled = false

  backup_retention_days        = 14
  geo_redundant_backup_enabled = false

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.pg,
    azurerm_subnet_nat_gateway_association.db,
  ]
}

resource "azurerm_postgresql_flexible_server_configuration" "wal_level" {
  name      = "wal_level"
  server_id = azurerm_postgresql_flexible_server.flexible_server.id
  value     = "logical"
}

resource "azurerm_postgresql_flexible_server_configuration" "max_worker_processes" {
  name      = "max_worker_processes"
  server_id = azurerm_postgresql_flexible_server.flexible_server.id
  value     = "16"
}
