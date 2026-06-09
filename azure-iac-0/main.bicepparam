using './main.bicep'

// Prefix applied to resource names (for example, js-core-rg, js-hub-vnet).
param namePrefix = 'js'

// Azure region for the core resource group and deployed modules.
param location = 'eastus2'

// Base IPv4 address for the hub virtual network, without the CIDR suffix (for example, 10.0.0.0).
param ipAddressSpace = '10.0.0.0'

// CIDR suffix for the hub VNet, including the leading slash (for example, /16).
param CIDR = '/16'

// Replication SKU for the core storage account (LRS or zone-redundant ZRS).
param storageSku = 'Standard_LRS'

// Name of the hub virtual network.
param networkName = '${namePrefix}-${location}-hub-vnet'

// Company domain for the private dns zone.
param companyDomain = '${namePrefix}-company.com'
