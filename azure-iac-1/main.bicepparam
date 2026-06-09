using './main.bicep'

// Prefix applied to resource names (for example, js-core-rg, js-hub-vnet).
param namePrefix = 'js'

// Azure region for the core resource group and deployed modules.
param location = 'centralus'

// Base IPv4 address for the hub virtual network, without the CIDR suffix (for example, 10.0.0.0).
param ipAddressSpace = '10.1.0.0'

// CIDR suffix for the hub VNet, including the leading slash (for example, /16).
param CIDR = '/16'

// Replication SKU for the core storage account (LRS or zone-redundant ZRS).
param storageSku = 'Standard_LRS'

// Name of the virtual network to create.
param networkName = '${namePrefix}-${location}-hub-vnet'

// Name of the hub virtual network to peer with.
param hubNetworkName = 'js-eastus2-hub-vnet'

// Resource group that hosts the private dns zone.
param hubResourceGroupName = 'js-eastus2-core-rg'

// Company domain for the private dns zone.
param companyDomain = 'js-company.com'
