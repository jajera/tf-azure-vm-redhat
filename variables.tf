variable "subscription_id" {
  type        = string
  description = "The ID of the Azure subscription to deploy resources to"
}

variable "location" {
  type        = string
  description = "The Azure region to deploy resources to"
  default     = "australiaeast"
}

variable "vm_admin_username" {
  type        = string
  description = "Admin username for the VM"
  default     = "azureuser"
}

variable "vm_size" {
  type        = string
  description = "Size of the VM"
  default     = "Standard_B2s"
}

variable "enable_bastion" {
  type        = bool
  description = "Enable Azure Bastion for secure VM access"
  default     = true
}
