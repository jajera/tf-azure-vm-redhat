# Generate random password
resource "random_password" "this" {
  length  = 16
  special = true
}

# Data source to get the latest RedHat image
data "azurerm_platform_image" "this" {
  location  = var.location
  publisher = "RedHat"
  offer     = "RHEL"
  sku       = "9-lvm-gen2"
}

# Resource Group
resource "azurerm_resource_group" "this" {
  name     = "tf-rg-redhat-demo"
  location = var.location

  tags = local.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "this" {
  name                = "tf-vnet-redhat-demo"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  tags = local.common_tags
}

# Subnet for VM
resource "azurerm_subnet" "this" {
  name                 = "tf-subnet-redhat-demo"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Bastion Subnet (required name for Azure Bastion)
resource "azurerm_subnet" "bastion" {
  count                = var.enable_bastion ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Public IP for NAT Gateway
resource "azurerm_public_ip" "nat" {
  name                = "tf-pip-nat-redhat-demo"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(local.common_tags, {
    Resource = "nat-gateway"
  })
}

# NAT Gateway for VM internet access
resource "azurerm_nat_gateway" "this" {
  name                    = "tf-nat-redhat-demo"
  location                = azurerm_resource_group.this.location
  resource_group_name     = azurerm_resource_group.this.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10

  tags = local.common_tags
}

# Associate NAT Gateway with Public IP
resource "azurerm_nat_gateway_public_ip_association" "this" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

# Associate NAT Gateway with Subnet
resource "azurerm_subnet_nat_gateway_association" "this" {
  subnet_id      = azurerm_subnet.this.id
  nat_gateway_id = azurerm_nat_gateway.this.id
}

# Network Security Group - Allow SSH from Bastion only
resource "azurerm_network_security_group" "this" {
  name                = "tf-nsg-redhat-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  security_rule {
    name                       = "AllowSSHFromBastion"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAllOutbound"
    priority                   = 1004
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

# Public IP for Bastion
resource "azurerm_public_ip" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  name                = "tf-pip-bastion-redhat-demo"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(local.common_tags, {
    Resource = "bastion"
  })
}

# Network Interface for VM (private only)
resource "azurerm_network_interface" "this" {
  name                = "tf-nic-redhat-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = merge(local.common_tags, {
    Resource = "network-interface"
  })
}

# Azure Bastion
resource "azurerm_bastion_host" "this" {
  count               = var.enable_bastion ? 1 : 0
  name                = "tf-bastion-redhat-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                 = "ipconfig1"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  tags = merge(local.common_tags, {
    Resource = "bastion"
  })
}

# RedHat VM using data source for latest image
resource "azurerm_linux_virtual_machine" "this" {
  name                = "tf-vm-redhat-demo"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = var.vm_size
  admin_username      = var.vm_admin_username
  admin_password      = random_password.this.result

  # Use latest RedHat image from data source
  source_image_reference {
    publisher = data.azurerm_platform_image.this.publisher
    offer     = data.azurerm_platform_image.this.offer
    sku       = data.azurerm_platform_image.this.sku
    version   = data.azurerm_platform_image.this.version
  }

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.this.id,
  ]

  os_disk {
    name                 = "tf-osdisk-redhat-demo"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  tags = merge(local.common_tags, {
    Resource = "virtual-machine"
    OS       = "RedHat"
    Image    = data.azurerm_platform_image.this.sku
  })
}
