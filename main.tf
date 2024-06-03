
##############################################################

locals {
  resource_group_name = "roopesh-terraform-test-rg"
  location            = "eastus"
  virtual_Network = {
    name          = "virtualNetwork1"
    address_space = ["10.0.0.0/16"]
  }
  subnets = [
    {
      name           = "subnetA"
      address_prefix = "10.0.1.0/24"
    },
    {
      name           = "subnetB"
      address_prefix = "10.0.2.0/24"
    }
  ]
}

################ RG ##########################
resource "azurerm_resource_group" "resource_group01" {
  name     = local.resource_group_name
  location = local.location
}
################# Vnet #######################
resource "azurerm_virtual_network" "vnet" {
  name                = local.virtual_Network.name
  location            = local.location
  resource_group_name = local.resource_group_name
  address_space       = local.virtual_Network.address_space

  subnet {
    name           = local.subnets[0].name
    address_prefix = local.subnets[0].address_prefix
  }

  subnet {
    name           = local.subnets[1].name
    address_prefix = local.subnets[1].address_prefix
  }
  depends_on = [azurerm_resource_group.resource_group01]
}
# ################# Subnets #######################
# resource "azurerm_subnet" "subnet" {
#   name                 = local.subnets[0].name
#   virtual_network_name = azurerm_virtual_network.vnet.name
#   resource_group_name  = azurerm_resource_group.resource_group01.name
#   address_prefixes     = [local.subnets[0].address_prefix]
#   depends_on           = [azurerm_virtual_network.vnet]
# }
# resource "azurerm_subnet" "subnet1" {
#   name                 = local.subnets[1].name
#   virtual_network_name = azurerm_virtual_network.vnet.name
#   resource_group_name  = azurerm_resource_group.resource_group01.name
#   address_prefixes     = [local.subnets[1].address_prefix]
#   depends_on           = [azurerm_virtual_network.vnet]
# }
################# NSG #######################
resource "azurerm_network_security_group" "nsg" {
  name                = "Terraform-nsg"
  location            = local.location
  resource_group_name = local.resource_group_name
  security_rule {
    name                       = "allow3389"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  depends_on = [azurerm_resource_group.resource_group01]
}

resource "azurerm_subnet_network_security_group_association" "subnet_association" {
  subnet_id                 = tolist(azurerm_virtual_network.vnet.subnet)[0].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

################# NIC #######################
resource "azurerm_network_interface" "nic" {
  name                = "terraform-nic"
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = tolist(azurerm_virtual_network.vnet.subnet)[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.PIP.id
  }
  depends_on = [azurerm_resource_group.resource_group01]
}
resource "azurerm_network_interface" "nic2" {
  name                = "terraform-nic2"
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = tolist(azurerm_virtual_network.vnet.subnet)[0].id
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id          = azurerm_public_ip.PIP.id
  }
  depends_on = [azurerm_resource_group.resource_group01]
}

#################### Public IP ####################
resource "azurerm_public_ip" "PIP" {
  name                = "to-nic_pip"
  resource_group_name = local.resource_group_name
  location            = local.location
  allocation_method   = "Static"
  depends_on          = [azurerm_resource_group.resource_group01]
}

##################### Virtual Machine ######################

resource "azurerm_windows_virtual_machine" "vm" {
  name                = "TerraformVM"
  resource_group_name = local.resource_group_name
  location            = local.location
  size                = "Standard_F2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic.id, azurerm_network_interface.nic2.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  depends_on = [ azurerm_resource_group.resource_group01, azurerm_network_interface.nic, azurerm_network_interface.nic2 ]
}
##################### adding a DATA Disk ########################
resource "azurerm_managed_disk" "disk" {
  name                 = "data_disk"
  location             = local.location
  resource_group_name  = local.resource_group_name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1"
  depends_on = [ azurerm_windows_virtual_machine.vm]
}
######################### Attaching the data disk ###################
resource "azurerm_virtual_machine_data_disk_attachment" "disk-attachment" {
  managed_disk_id    = azurerm_managed_disk.disk.id
  virtual_machine_id = azurerm_windows_virtual_machine.vm.id
  lun                = "10"
  caching            = "ReadWrite"
}

# ############## OUTPUT BLOCK ########################

# output "subnetA-id" {
#   value = azurerm_virtual_network.vnet.subnet
# }
#################### Storage Account ###################
# resource "azurerm_storage_account" "sttg" {
#   name                     = "sttg009374"
#   location                 = "eastus"
#   resource_group_name      = "my-rg"
#   account_tier             = "Standard"
#   account_replication_type = "GRS"
#   access_tier              = "Cool"
# }
################# container ############################
# resource "azurerm_storage_container" "container" {
#   name                  = "mycontainer"
#   storage_account_name  = azurerm_storage_account.sttg.name
#   container_access_type = "private"
# }
################### blob in container #################
# resource "azurerm_storage_blob" "blob" {
#   name                   = "blob"
#   storage_account_name   = azurerm_storage_account.sttg.name
#   storage_container_name = azurerm_storage_container.container.name
#   type                   = "Block"
#   source                 = "main.tf"
# }

















































