output "bastion_connection_info" {
  description = "Connection information for accessing the VM via Azure Bastion"
  value = var.enable_bastion ? {
    bastion_name      = azurerm_bastion_host.this[0].name
    connection_method = "Use the Azure Portal to connect via Bastion"
    portal_url        = "https://portal.azure.com"
    username          = var.vm_admin_username
    } : {
    message = "Bastion is disabled. No secure connection available."
  }
}

output "vm_connection_info" {
  description = "Complete connection information for the VM"
  value = {
    vm_name    = azurerm_linux_virtual_machine.this.name
    username   = var.vm_admin_username
    private_ip = azurerm_network_interface.this.private_ip_address
    rg_name    = azurerm_resource_group.this.name
    region     = var.location
    vm_size    = var.vm_size
  }
}

output "vm_image_info" {
  description = "Information about the VM image"
  value = {
    publisher = data.azurerm_platform_image.this.publisher
    offer     = data.azurerm_platform_image.this.offer
    sku       = data.azurerm_platform_image.this.sku
    version   = data.azurerm_platform_image.this.version
  }
}

output "vm_admin_password" {
  description = "Admin password for the VM"
  value       = random_password.this.result
  sensitive   = true
}
