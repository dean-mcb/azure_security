terraform {
  required_version = ">=0.12"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~>1.5"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "my_rg" {
  name     = "my-rg"
  location = "southafricanorth"
  tags = {
    environment = "dev"
    source      = "Terraform"
  }

}

# Virtual Network
resource "azurerm_virtual_network" "my_vnet" {
  name                = "my-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "southafricanorth"
  resource_group_name = azurerm_resource_group.my_rg.name
}

# Firewall Subnet 
resource "azurerm_subnet" "my_firewall_subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.my_rg.name
  virtual_network_name = azurerm_virtual_network.my_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Private Subnet 
resource "azurerm_subnet" "my_private_subnet" {
  name                 = "my-private-subnet"
  resource_group_name  = azurerm_resource_group.my_rg.name
  virtual_network_name = azurerm_virtual_network.my_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# AzureBastionSubnet Subnet 
resource "azurerm_subnet" "AzureBastionSubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.my_rg.name
  virtual_network_name = azurerm_virtual_network.my_vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

# Create a public IP for Bastion
resource "azurerm_public_ip" "bastion_pub_ip" {
  name                = "bastion-pub-ip"
  location            = azurerm_resource_group.my_rg.location
  resource_group_name = azurerm_resource_group.my_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "my_nsg" {
  name                = "my-nsg"
  location            = azurerm_resource_group.my_rg.location
  resource_group_name = azurerm_resource_group.my_rg.name

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


# Create private network interface
resource "azurerm_network_interface" "my_private_nic" {
  name                = "my-private-nic"
  location            = azurerm_resource_group.my_rg.location
  resource_group_name = azurerm_resource_group.my_rg.name

  ip_configuration {
    name                          = "my_private_nic_config"
    subnet_id                     = azurerm_subnet.my_private_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create private network interface linux
resource "azurerm_network_interface" "my_private_nic_linux" {
  name                = "my-private-nic-linux"
  location            = azurerm_resource_group.my_rg.location
  resource_group_name = azurerm_resource_group.my_rg.name

  ip_configuration {
    name                          = "my_private_nic_config"
    subnet_id                     = azurerm_subnet.my_private_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}



# Connect the security group to the PRIVATE network interface
resource "azurerm_network_interface_security_group_association" "private_nic_association" {
  network_interface_id      = azurerm_network_interface.my_private_nic.id
  network_security_group_id = azurerm_network_security_group.my_nsg.id
}


# Create the Bastion
resource "azurerm_bastion_host" "my_bastion" {
  name                = "my-bastion"
  location            = azurerm_resource_group.my_rg.location
  resource_group_name = azurerm_resource_group.my_rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.AzureBastionSubnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pub_ip.id
  }
}

# Create PRIVATE virtual machine - Windows
resource "azurerm_windows_virtual_machine" "private_vm" {
  name                  = "workhost"
  admin_username        = "azureuser"
  admin_password        = "Techytechy11!!"
  location              = azurerm_resource_group.my_rg.location
  resource_group_name   = azurerm_resource_group.my_rg.name
  network_interface_ids = [azurerm_network_interface.my_private_nic.id]
  size                  = "Standard_B1s"

  os_disk {
    name                 = "workOsDisk2"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

}


# Create PRIVATE virtual machine - Linux
resource "azurerm_linux_virtual_machine" "private_vm_linux" {
  name                  = "workhost-linux"
  admin_username        = "azureuser"
  admin_password        = "Techytechy11!!"
  location              = azurerm_resource_group.my_rg.location
  resource_group_name   = azurerm_resource_group.my_rg.name
  network_interface_ids = [azurerm_network_interface.my_private_nic_linux.id]
  size                  = "Standard_B1s"

  os_disk {
    name                 = "workOsDiskLinux"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = azapi_resource_action.ssh_public_key_gen.output.publicKey
  }

}


# Create an Azure FIREWALL
resource "azurerm_public_ip" "my_fw_pub_ip" {
  name                = "my-fw-pub-ip"
  location            = azurerm_resource_group.my_rg.location
  resource_group_name = azurerm_resource_group.my_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "my_firewall" {
  name                = "my-firewall"
  location            = azurerm_resource_group.my_rg.location
  resource_group_name = azurerm_resource_group.my_rg.name
  
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.my_firewall_subnet.id
    public_ip_address_id = azurerm_public_ip.my_fw_pub_ip.id
  }
}

