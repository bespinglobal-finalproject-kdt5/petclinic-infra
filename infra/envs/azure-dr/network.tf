# VNet 10.30.0.0/25. 퍼블릭 서브넷 없음. 앞에서부터 칸을 붙였다.
#   10.30.0.0/27   private  0–31    Pet-DR-vm (앱은 컨테이너)
#   10.30.0.32/27  db       32–63   Flexible Server
#   10.30.0.64/26  예비     64–127  서브넷 안 만듦
# 노트북 입구는 VM 공인 IP. NAT 출구는 Public-IP. Application Gateway 없음.

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "services_vnet" {
  name                = "Services-VNet"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  address_space       = ["10.30.0.0/25"]
}

resource "azurerm_subnet" "private" {
  name                 = "Pet-DR-private-1"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.services_vnet.name
  address_prefixes     = ["10.30.0.0/27"]
}

resource "azurerm_subnet" "db" {
  name                 = "Pet-DR-db-1"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.services_vnet.name
  address_prefixes     = ["10.30.0.32/27"]

  delegation {
    name = "postgresql-flexible"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_public_ip" "public_ip" {
  name                = "Public-IP"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [var.zone]
}

resource "azurerm_nat_gateway" "nat_gateway" {
  name                = "NAT-Gateway"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  sku_name            = "Standard"
  zones               = [var.zone]
}

resource "azurerm_nat_gateway_public_ip_association" "nat_gateway" {
  nat_gateway_id       = azurerm_nat_gateway.nat_gateway.id
  public_ip_address_id = azurerm_public_ip.public_ip.id
}

resource "azurerm_subnet_nat_gateway_association" "private" {
  subnet_id      = azurerm_subnet.private.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway.id
}

resource "azurerm_subnet_nat_gateway_association" "db" {
  subnet_id      = azurerm_subnet.db.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway.id
}
