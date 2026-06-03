targetScope = 'subscription'
metadata description = 'Subscription-scoped landing zone: core resource group, hub network, Key Vault, and storage.'

@description('Azure region for the core resource group and deployed modules.')
param location string

@description('Prefix applied to resource names (for example, js-core-rg, js-hub-vnet).')
param namePrefix string

@description('Replication SKU for the core storage account (LRS or zone-redundant ZRS).')
@allowed([
  'Standard_LRS'
  //'Standard_ZRS'
])
param storageSku string

@description('Base IPv4 address for the hub virtual network, without the CIDR suffix (for example, 10.0.0.0).')
param ipAddressSpace string

@description('CIDR suffix for the hub VNet, including the leading slash (for example, /16).')
param CIDR string

@description('Resource group that hosts core landing-zone networking, secrets, and storage.')
resource coreResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${namePrefix}-core-rg'
  location: location
}

@description('Hub virtual network with Firewall, Gateway, and Bastion subnets.')
module coreVNet '../modules/networkhub.bicep' = {
  scope: coreResourceGroup
  params:{
    location: location
    CIDR: CIDR
    ipAddressSpace: ipAddressSpace 
    namePrefix: namePrefix
  }
}

@description('Key Vault for secrets and certificates used by the landing zone.')
module coreKeyvault '../modules/keyvault.bicep' = {
  scope: coreResourceGroup
  params: {
    location: location
    namePrefix: namePrefix
  }
}

@description('Core storage account for diagnostics, artifacts, or shared blob data.')
module coreStorage '../modules/storage.bicep' = {
  scope: coreResourceGroup
  params: {
    namePrefix: namePrefix
    storageSku: storageSku
  }
}
