provider "azurerm" {
  features {}
}

terraform {
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = "0.7.2"  # Make sure to use the version that match latest version
    }
  }
}


variable "location" {
  default = "East US"
}

variable "myname" {
  default = "igork"
}


variable "vm_size" {
  default = "Standard_B1ms"
}

variable "admin_username" {
  default = "adminuser-igork"
}

variable "admin_password" {
  default = "Password123!"
}


resource "azurerm_resource_group" "rg-igork" {
  name     = "${var.myname}-resources"
  location = var.location
}

resource "azurerm_virtual_network" "vnet-igork" {
  name                = "${var.myname}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-igork.name
}

resource "azurerm_subnet" "subnet-igork" {
  name                 = "${var.myname}-subnet"
  resource_group_name  = azurerm_resource_group.rg-igork.name
  virtual_network_name = azurerm_virtual_network.vnet-igork.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "pip-igork" {
  name                = "${var.myname}-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-igork.name
  allocation_method   = "Dynamic"  # Dynamic IP allocation for Basic SKU
  sku = "Basic"  
}

# Use Basic SKU (Stock Keeping Unit - azure tiers) for dynamic IP

resource "azurerm_network_interface" "nic-igork" {
  name                = "${var.myname}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-igork.name

  ip_configuration {
    name                          = "igork-ipconfig"
    subnet_id                     = azurerm_subnet.subnet-igork.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip-igork.id
  }
}


resource "azurerm_linux_virtual_machine" "vm-igork" {
  name                  = "${var.myname}-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg-igork.name
  network_interface_ids = [azurerm_network_interface.nic-igork.id]
  size                  = var.vm_size

  os_disk {
    name              = "${var.myname}-os-disk"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_username = var.admin_username
  admin_password = var.admin_password

  disable_password_authentication = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name = "${var.myname}-vm"
}

output "vm_public_ip" {
  value = azurerm_public_ip.pip-igork.ip_address
  description = "Public IP address of the VM"
  depends_on = [null_resource.validate_ip ]
}


resource "null_resource" "validate_ip" {
  provisioner "local-exec" {
        command = <<EOT
      if [ -z "${azurerm_public_ip.pip-igork.ip_address}" ]; then
        echo "ERROR: Public IP address was not assigned." >&2
        exit 1
      fi
    EOT
  }
  depends_on = [ azurerm_public_ip.pip-igork, time_sleep.wait_for_ip ]
}

resource "time_sleep" "wait_for_ip" {
  create_duration = "30s"  # Wait for 30 seconds
}


