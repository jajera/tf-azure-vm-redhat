# Create resource group
resource "azurerm_resource_group" "rg" {
  name     = "vm-redhat"
  location = "Southeast Asia"
  tags = {
    "use_case" = "redhat vm demo"
  }
}

data "azurerm_subscriptions" "current" {}

data "azurerm_subscription" "primary" {}

data "azurerm_client_config" "current" {}

# Generate random string as prefix to all resources
resource "random_string" "prefix" {
  length  = 5
  special = false
  upper   = true
  lower   = false
  numeric = false
}

# Generate random password for vm
resource "random_password" "redhat" {
  length      = 16
  min_lower   = 2
  min_numeric = 2
  min_upper   = 2
  special     = false
}

# Create nsg for workstation
resource "azurerm_network_security_group" "nsg" {
  name                = "${random_string.prefix.result}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule = [
    {
      access                                     = "Allow"
      description                                = ""
      destination_address_prefix                 = "*"
      destination_address_prefixes               = []
      destination_application_security_group_ids = []
      destination_port_range                     = "22"
      destination_port_ranges                    = []
      direction                                  = "Inbound"
      name                                       = "SSH-In"
      priority                                   = 1010
      protocol                                   = "Tcp"
      source_address_prefix                      = "116.86.224.253"
      source_address_prefixes                    = []
      source_application_security_group_ids      = []
      source_port_range                          = "*"
      source_port_ranges                         = []
    }
  ]

  tags = azurerm_resource_group.rg.tags
}

# Virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "${random_string.prefix.result}-vnet"
  address_space       = ["10.8.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = azurerm_resource_group.rg.tags
}

# Create vm subnet
resource "azurerm_subnet" "vm" {
  name                 = "vm"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.8.8.0/24"]
}

# Associate nsg to to vm subnet
resource "azurerm_subnet_network_security_group_association" "vm" {
  subnet_id                 = azurerm_subnet.vm.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create vm public ip
resource "azurerm_public_ip" "redhat" {
  name                = "${random_string.prefix.result}-redhat"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = azurerm_resource_group.rg.tags
}

# Create vm network card
resource "azurerm_network_interface" "redhat" {
  name                = "${random_string.prefix.result}-redhat"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "default"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"

    public_ip_address_id = azurerm_public_ip.redhat.id
  }

  tags = azurerm_resource_group.rg.tags
}

# Create redhat vm
resource "azurerm_linux_virtual_machine" "redhat" {
  name                = "${random_string.prefix.result}-redhat"
  computer_name       = "redhat"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "devops"
  admin_password      = random_password.redhat.result

  network_interface_ids = [
    azurerm_network_interface.redhat.id,
  ]

  os_disk {
    caching                   = "ReadWrite"
    storage_account_type      = "Premium_LRS"
    name                      = "${random_string.prefix.result}-redhat-disk1"
    disk_size_gb              = 64
    write_accelerator_enabled = false
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "86-gen2"
    version   = "latest"
  }

  disable_password_authentication = false

  tags = azurerm_resource_group.rg.tags
}

# # Enable gui
# resource "null_resource" "redhat_enablegui" {
#   # triggers = {
#   #   always_run = "${timestamp()}"
#   # }

#   connection {
#     type     = "ssh"
#     user     = azurerm_linux_virtual_machine.redhat.admin_username
#     password = azurerm_linux_virtual_machine.redhat.admin_password
#     host     = azurerm_linux_virtual_machine.redhat.public_ip_address
#     timeout = "15m"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "sudo yum update -y",
#       "sudo yum groupinstall -y \"Server with GUI\"",
#       "sudo systemctl set-default graphical.target",
#       "sudo yum update -y"
#     ]
#   }

#   depends_on = [
#     azurerm_linux_virtual_machine.redhat
#   ]
# }

# # Trigger reboot
# resource "null_resource" "redhat_triggerreboot" {
#   # triggers = {
#   #   always_run = "${timestamp()}"
#   # }

#   connection {
#     type        = "ssh"
#     user     = azurerm_linux_virtual_machine.redhat.admin_username
#     password = azurerm_linux_virtual_machine.redhat.admin_password
#     host     = azurerm_linux_virtual_machine.redhat.public_ip_address
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "sudo reboot &"
#     ]   
#   }

#   depends_on = [
#     null_resource.redhat_enablegui
#   ]
# }

# Install baseapps
resource "null_resource" "redhat_baseapps" {
  # triggers = {
  #   always_run = "${timestamp()}"
  # }

  connection {
    type     = "ssh"
    user     = azurerm_linux_virtual_machine.redhat.admin_username
    password = azurerm_linux_virtual_machine.redhat.admin_password
    host     = azurerm_linux_virtual_machine.redhat.public_ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y curl",
      "sudo yum install -y wget",
      "sudo yum install -y git",
      "sudo yum install -y gnupg",
      "sudo yum install -y initscripts",
      "sudo yum install -y iputils",
      "sudo yum install -y bind-utils",
      "sudo yum install -y yum-utils",
      "sudo yum install -y net-tools",
      "sudo yum install -y sshpass",
      "sudo yum install -y make",
      "sudo yum install -y gcc",
      "sudo yum install -y openssl-devel",
      "sudo yum install -y bzip2-devel",
      "sudo yum install -y libffi-devel",
      "sudo yum install -y zlib-devel",
      "sudo yum install -y jq",
      "sudo yum install -y tar",
      "sudo yum -y module enable python38:3.8 && sudo yum install -y python39"
    ]
  }

  depends_on = [
    azurerm_linux_virtual_machine.redhat
  ]
}

# Install azurecli
resource "null_resource" "redhat_azurecli" {
  # triggers = {
  #   always_run = "${timestamp()}"
  # }

  connection {
    type     = "ssh"
    user     = azurerm_linux_virtual_machine.redhat.admin_username
    password = azurerm_linux_virtual_machine.redhat.admin_password
    host     = azurerm_linux_virtual_machine.redhat.public_ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc",
      "sudo sh -c 'echo -e \"[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\" > /etc/yum.repos.d/azure-cli.repo'",
      "sudo yum install -y azure-cli"
    ]
  }

  depends_on = [
    null_resource.redhat_baseapps
  ]
}

# Install helm
resource "null_resource" "redhat_helm" {
  # triggers = {
  #   always_run = "${timestamp()}"
  # }

  connection {
    type     = "ssh"
    user     = azurerm_linux_virtual_machine.redhat.admin_username
    password = azurerm_linux_virtual_machine.redhat.admin_password
    host     = azurerm_linux_virtual_machine.redhat.public_ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 > get_helm.sh",
      "chmod +x get_helm.sh",
      "./get_helm.sh"
    ]
  }

  depends_on = [
    null_resource.redhat_azurecli
  ]
}

# Install kubectl
resource "null_resource" "redhat_kubectl" {
  # triggers = {
  #   always_run = "${timestamp()}"
  # }

  connection {
    type     = "ssh"
    user     = azurerm_linux_virtual_machine.redhat.admin_username
    password = azurerm_linux_virtual_machine.redhat.admin_password
    host     = azurerm_linux_virtual_machine.redhat.public_ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\"",
      "chmod +x kubectl",
      "sudo mv kubectl /usr/local/bin/"
    ]
  }

  depends_on = [
    null_resource.redhat_helm
  ]
}

# Install dockercli
resource "null_resource" "redhat_dockercli" {
  # triggers = {
  #   always_run = "${timestamp()}"
  # }

  connection {
    type     = "ssh"
    user     = azurerm_linux_virtual_machine.redhat.admin_username
    password = azurerm_linux_virtual_machine.redhat.admin_password
    host     = azurerm_linux_virtual_machine.redhat.public_ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo",
      "sudo yum install -y docker-ce",
      "sudo yum install -y docker-ce-cli",
      "sudo yum install -y containerd.io",
      "sudo yum install -y docker-buildx-plugin",
      "sudo yum install -y docker-compose-plugin"
    ]
  }

  depends_on = [
    null_resource.redhat_kubectl
  ]
}

# Install terraformcli
resource "null_resource" "redhat_terraformcli" {
  # triggers = {
  #   always_run = "${timestamp()}"
  # }

  connection {
    type     = "ssh"
    user     = azurerm_linux_virtual_machine.redhat.admin_username
    password = azurerm_linux_virtual_machine.redhat.admin_password
    host     = azurerm_linux_virtual_machine.redhat.public_ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "curl -LO https://releases.hashicorp.com/terraform/1.4.5/terraform_1.4.5_linux_amd64.zip",
      "sudo unzip terraform_1.4.5_linux_amd64.zip -d /usr/local/bin/",
      "sudo chmod +x /usr/local/bin/terraform",
      "terraform --version"
    ]
  }

  depends_on = [
    null_resource.redhat_dockercli
  ]
}

# Perform cleanup
resource "null_resource" "redhat_cleanup" {
  # triggers = {
  #   always_run = "${timestamp()}"
  # }

  connection {
    type     = "ssh"
    user     = azurerm_linux_virtual_machine.redhat.admin_username
    password = azurerm_linux_virtual_machine.redhat.admin_password
    host     = azurerm_linux_virtual_machine.redhat.public_ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum clean all"
    ]
  }

  depends_on = [
    null_resource.redhat_terraformcli
  ]
}
