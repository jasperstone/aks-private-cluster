resource "azurerm_resource_group" "res-0" {
  location = "eastus"
  name     = "aks-rg"
}
resource "azurerm_kubernetes_cluster" "res-1" {
  dns_prefix                          = "aks-aks-rg-9490ee"
  location                            = "eastus"
  name                                = "aks"
  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = true
  resource_group_name                 = "aks-rg"
  default_node_pool {
    name           = "nodepool1"
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/aks-rg/providers/Microsoft.Network/virtualNetworks/aks-vnet/subnets/aks-subnet"
  }
  identity {
    identity_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/aks-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/controlPlaneIdentity"]
    type         = "UserAssigned"
  }
  linux_profile {
    admin_username = "azureuser"
    ssh_key {
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1raCiRg8cxJnKsfFhcEc/dG4R0S/MmbVUZMJKV7DMI6EPaT9O9EnN9bSDHy2QzreOGRxmoUwUSbjZiIGcTmm6zmQV0tqNFwF5m4O8dRvVvbqwnrhPbVLeNiUeZZtRB6fNt5lqxYhXH/Nm3QEMyOxBzm40AkbB3IrbRFOTFVwl0Zt1r8QmBw7V0uMkKuDdIqDIDkp7dz18MW1N6vfPsOx+2DPuQUn6eO/eZzOhxrkTsplNo4x51KbCAff8EDPVGT1zrteV2xBuTN0l3QsDFAz14Zgqf9sWAO+w02LOxUf2Uu5Lx5ZvBH+GJFl2PJkbeXz9AsNmAInXjlO74zJyCHIR"
    }
  }
  depends_on = [
    azurerm_user_assigned_identity.res-3,
    # One of azurerm_subnet.res-15,azurerm_subnet_route_table_association.res-16 (can't auto-resolve as their ids are identical)
  ]
}
resource "azurerm_kubernetes_cluster_node_pool" "res-2" {
  kubernetes_cluster_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/aks-rg/providers/Microsoft.ContainerService/managedClusters/aks"
  mode                  = "System"
  name                  = "nodepool1"
  vm_size               = "Standard_DS2_v2"
  vnet_subnet_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/aks-rg/providers/Microsoft.Network/virtualNetworks/aks-vnet/subnets/aks-subnet"
  workload_runtime      = "OCIContainer"
  depends_on = [
    azurerm_kubernetes_cluster.res-1,
    # One of azurerm_subnet.res-15,azurerm_subnet_route_table_association.res-16 (can't auto-resolve as their ids are identical)
  ]
}
resource "azurerm_user_assigned_identity" "res-3" {
  location            = "eastus"
  name                = "controlPlaneIdentity"
  resource_group_name = "aks-rg"
  depends_on = [
    azurerm_resource_group.res-0,
  ]
}
resource "azurerm_user_assigned_identity" "res-4" {
  location            = "eastus"
  name                = "kubeletIdentity"
  resource_group_name = "aks-rg"
  depends_on = [
    azurerm_resource_group.res-0,
  ]
}
resource "azurerm_firewall" "res-5" {
  location            = "eastus"
  name                = "aks-fw"
  resource_group_name = "aks-rg"
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  ip_configuration {
    name                 = "aks-fwconfig"
    public_ip_address_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/aks-rg/providers/Microsoft.Network/publicIPAddresses/aks-fwpublicip"
    subnet_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/aks-rg/providers/Microsoft.Network/virtualNetworks/aks-vnet/subnets/AzureFirewallSubnet"
  }
  depends_on = [
    azurerm_public_ip.res-6,
    azurerm_subnet.res-14,
  ]
}
resource "azurerm_public_ip" "res-6" {
  allocation_method   = "Static"
  location            = "eastus"
  name                = "aks-fwpublicip"
  resource_group_name = "aks-rg"
  sku                 = "Standard"
  depends_on = [
    azurerm_resource_group.res-0,
  ]
}
resource "azurerm_route_table" "res-7" {
  location            = "eastus"
  name                = "aks-fwrt"
  resource_group_name = "aks-rg"
  depends_on = [
    azurerm_resource_group.res-0,
  ]
}
resource "azurerm_route" "res-8" {
  address_prefix      = "157.56.178.157/32"
  name                = "aks-fwinternet"
  next_hop_type       = "Internet"
  resource_group_name = "aks-rg"
  route_table_name    = "aks-fwrt"
  depends_on = [
    azurerm_route_table.res-7,
  ]
}
resource "azurerm_route" "res-9" {
  address_prefix         = "0.0.0.0/0"
  name                   = "aks-fwrn"
  next_hop_in_ip_address = "10.42.2.4"
  next_hop_type          = "VirtualAppliance"
  resource_group_name    = "aks-rg"
  route_table_name       = "aks-fwrt"
  depends_on = [
    azurerm_route_table.res-7,
  ]
}
resource "azurerm_route" "res-10" {
  address_prefix         = "10.244.0.0/24"
  name                   = "aks-nodepool1-40643304-vmss000000____102440024"
  next_hop_in_ip_address = "10.42.1.7"
  next_hop_type          = "VirtualAppliance"
  resource_group_name    = "aks-rg"
  route_table_name       = "aks-fwrt"
  depends_on = [
    azurerm_route_table.res-7,
  ]
}
resource "azurerm_route" "res-11" {
  address_prefix         = "10.244.2.0/24"
  name                   = "aks-nodepool1-40643304-vmss000001____102442024"
  next_hop_in_ip_address = "10.42.1.6"
  next_hop_type          = "VirtualAppliance"
  resource_group_name    = "aks-rg"
  route_table_name       = "aks-fwrt"
  depends_on = [
    azurerm_route_table.res-7,
  ]
}
resource "azurerm_route" "res-12" {
  address_prefix         = "10.244.1.0/24"
  name                   = "aks-nodepool1-40643304-vmss000002____102441024"
  next_hop_in_ip_address = "10.42.1.5"
  next_hop_type          = "VirtualAppliance"
  resource_group_name    = "aks-rg"
  route_table_name       = "aks-fwrt"
  depends_on = [
    azurerm_route_table.res-7,
  ]
}
resource "azurerm_virtual_network" "res-13" {
  address_space       = ["10.42.0.0/16"]
  location            = "eastus"
  name                = "aks-vnet"
  resource_group_name = "aks-rg"
  depends_on = [
    azurerm_resource_group.res-0,
  ]
}
resource "azurerm_subnet" "res-14" {
  address_prefixes     = ["10.42.2.0/24"]
  name                 = "AzureFirewallSubnet"
  resource_group_name  = "aks-rg"
  virtual_network_name = "aks-vnet"
  depends_on = [
    azurerm_virtual_network.res-13,
  ]
}
resource "azurerm_subnet" "res-15" {
  address_prefixes     = ["10.42.1.0/24"]
  name                 = "aks-subnet"
  resource_group_name  = "aks-rg"
  virtual_network_name = "aks-vnet"
  depends_on = [
    azurerm_virtual_network.res-13,
  ]
}
resource "azurerm_subnet_route_table_association" "res-16" {
  route_table_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/aks-rg/providers/Microsoft.Network/routeTables/aks-fwrt"
  subnet_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/aks-rg/providers/Microsoft.Network/virtualNetworks/aks-vnet/subnets/aks-subnet"
  depends_on = [
    azurerm_route_table.res-7,
    azurerm_subnet.res-15,
  ]
}
