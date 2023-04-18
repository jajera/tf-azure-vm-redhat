output "vm_ip" {
  value = azurerm_public_ip.redhat.ip_address
}

output "vm_username" {
  value = azurerm_linux_virtual_machine.redhat.admin_username
}

output "vm_password" {
  value = nonsensitive(azurerm_linux_virtual_machine.redhat.admin_password)
}
