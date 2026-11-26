# 그림 private 칸의 VM. Docker Compose 는 아직 안 깐다. Ubuntu 24.04 LTS 만 둔다.
# 노트북에서 SSH 하려고 NIC 에 공인 IP 를 붙인다. NSG 는 22 를 my_ip 만 연다.

resource "azurerm_public_ip" "vm" {
  name                = "Pet-DR-vm-pip"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [var.zone]
}

resource "azurerm_network_security_group" "vm" {
  name                = "Pet-DR-vm-nsg"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location

  security_rule {
    name                       = "ssh-from-laptop"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${var.my_ip}/32"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "vm" {
  name                = "Pet-DR-vm-nic"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "Pet-DR-vm"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  zone                = var.zone
  size                = "Standard_B2s"
  admin_username      = var.vm_admin_username

  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = var.vm_ssh_public_key
  }

  os_disk {
    name                 = "Pet-DR-vm-os"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
