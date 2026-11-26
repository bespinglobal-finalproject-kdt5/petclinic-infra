# AzureRM validates the shape of referenced ARM IDs even in a mock plan.
mock_data "azurerm_resource_group" {
  defaults = { location = "koreacentral" }
}

mock_resource "azurerm_virtual_network" {
  defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-dr/providers/Microsoft.Network/virtualNetworks/test-vnet" }
}

mock_resource "azurerm_nat_gateway" {
  defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-dr/providers/Microsoft.Network/natGateways/test-nat" }
}

mock_resource "azurerm_network_security_group" {
  defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-dr/providers/Microsoft.Network/networkSecurityGroups/test-nsg" }
}

mock_resource "azurerm_network_interface" {
  defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-dr/providers/Microsoft.Network/networkInterfaces/test-nic" }
}

mock_resource "azurerm_private_dns_zone" {
  defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-dr/providers/Microsoft.Network/privateDnsZones/test.postgres.database.azure.com" }
}

mock_resource "azurerm_postgresql_flexible_server" {
  defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-dr/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-pg" }
}
