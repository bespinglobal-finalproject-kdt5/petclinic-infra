mock_provider "azurerm" {
  source          = "./tests/mocks"
  override_during = plan
}

# Distinct IDs let a test catch a subnet or public IP being wired to the wrong resource.
override_resource {
  target          = azurerm_subnet.private
  override_during = plan
  values          = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-dr/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/app" }
}

override_resource {
  target          = azurerm_subnet.db
  override_during = plan
  values          = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-dr/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/db" }
}

override_resource {
  target          = azurerm_public_ip.vm
  override_during = plan
  values          = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-dr/providers/Microsoft.Network/publicIPAddresses/vm" }
}

override_resource {
  target          = azurerm_public_ip.public_ip
  override_during = plan
  values          = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-dr/providers/Microsoft.Network/publicIPAddresses/nat" }
}

variables {
  azure_subscription_id     = "00000000-0000-0000-0000-000000000001"
  resource_group_name       = "test-dr"
  my_ip                     = "192.0.2.23"
  vm_ssh_public_key         = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  db_administrator_password = "Synthetic-Only42!"
}

run "subnets_and_nat_egress" {
  command = plan

  assert {
    condition = (
      azurerm_virtual_network.services_vnet.resource_group_name == var.resource_group_name &&
      azurerm_virtual_network.services_vnet.location == "koreacentral" &&
      one(azurerm_virtual_network.services_vnet.address_space) == "10.30.0.0/25" &&
      one(azurerm_subnet.private.address_prefixes) == "10.30.0.0/27" &&
      one(azurerm_subnet.db.address_prefixes) == "10.30.0.32/27" &&
      azurerm_subnet.private.virtual_network_name == azurerm_virtual_network.services_vnet.name &&
      azurerm_subnet.db.virtual_network_name == azurerm_virtual_network.services_vnet.name
    )
    error_message = "The DR VNet must contain separate VM and PostgreSQL subnets in the existing resource group."
  }

  assert {
    condition = (
      azurerm_subnet_nat_gateway_association.private.subnet_id == azurerm_subnet.private.id &&
      azurerm_subnet_nat_gateway_association.db.subnet_id == azurerm_subnet.db.id &&
      azurerm_subnet_nat_gateway_association.private.nat_gateway_id == azurerm_nat_gateway.nat_gateway.id &&
      azurerm_subnet_nat_gateway_association.db.nat_gateway_id == azurerm_nat_gateway.nat_gateway.id &&
      azurerm_nat_gateway_public_ip_association.nat_gateway.nat_gateway_id == azurerm_nat_gateway.nat_gateway.id &&
      azurerm_nat_gateway_public_ip_association.nat_gateway.public_ip_address_id == azurerm_public_ip.public_ip.id
    )
    error_message = "Both subnets must use the NAT gateway associated with its dedicated outbound IP."
  }
}

run "private_postgresql" {
  command = plan

  assert {
    condition = (
      !azurerm_postgresql_flexible_server.flexible_server.public_network_access_enabled &&
      azurerm_postgresql_flexible_server.flexible_server.version == "16" &&
      azurerm_postgresql_flexible_server.flexible_server.delegated_subnet_id == azurerm_subnet.db.id &&
      one(one(azurerm_subnet.db.delegation).service_delegation).name == "Microsoft.DBforPostgreSQL/flexibleServers" &&
      azurerm_postgresql_flexible_server.flexible_server.private_dns_zone_id == azurerm_private_dns_zone.pg.id &&
      azurerm_private_dns_zone_virtual_network_link.pg.private_dns_zone_name == azurerm_private_dns_zone.pg.name &&
      azurerm_private_dns_zone_virtual_network_link.pg.virtual_network_id == azurerm_virtual_network.services_vnet.id
    )
    error_message = "PostgreSQL 16 must use the delegated DB subnet and private DNS linked to the DR VNet, with public access disabled."
  }
}

run "jump_vm_ssh" {
  command = plan

  assert {
    condition = (
      azurerm_linux_virtual_machine.vm.disable_password_authentication &&
      one(azurerm_linux_virtual_machine.vm.network_interface_ids) == azurerm_network_interface.vm.id &&
      one(azurerm_network_interface.vm.ip_configuration).subnet_id == azurerm_subnet.private.id &&
      one(azurerm_network_interface.vm.ip_configuration).public_ip_address_id == azurerm_public_ip.vm.id &&
      azurerm_network_interface_security_group_association.vm.network_interface_id == azurerm_network_interface.vm.id &&
      azurerm_network_interface_security_group_association.vm.network_security_group_id == azurerm_network_security_group.vm.id
    )
    error_message = "The SSH-only VM must use the protected NIC on the VM subnet with its own public IP."
  }

  assert {
    condition = (
      [for rule in azurerm_network_security_group.vm.security_rule : [rule.protocol, rule.destination_port_range, rule.source_address_prefix]
      if rule.direction == "Inbound" && rule.access == "Allow"] == [["Tcp", "22", "${var.my_ip}/32"]]
    )
    error_message = "The only custom inbound allow rule must permit TCP 22 from the operator's /32."
  }
}
