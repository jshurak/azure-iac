targetScope = 'subscription'
metadata description = 'Subscription-scoped landing zone: core resource group, hub network, Key Vault, and storage'

@description('Azure region for the core resource group and deployed modules.')
param location string

@description('Prefix applied to resource names (for example, js-core-rg, js-hub-vnet).')
param namePrefix string

@description('Replication SKU for the core storage account (LRS or zone-redundant ZRS).')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
])
param storageSku string

@description('Base IPv4 address for the hub virtual network, without the CIDR suffix (for example, 10.0.0.0).')
param ipAddressSpace string

@description('CIDR suffix for the hub VNet, including the leading slash (for example, /16).')
param CIDR string

@description('Name of the hub virtual network.')
param networkName string


@description('Company domain for the private dns zone.')
param companyDomain string


@description('Resource group that hosts core landing-zone networking, secrets, and storage.')
resource coreResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${namePrefix}-${location}-core-rg'
  location: location
}


module coreNetwork './network/network.bicep' = {
  scope: coreResourceGroup
  params: {
    companyDomain: companyDomain
    resourceGroupName: coreResourceGroup.name
    networkName: networkName
    namePrefix: namePrefix
    CIDR: CIDR
    ipAddressSpace: ipAddressSpace
  }
}


@description('Key Vault for secrets and certificates used by the landing zone.')
module coreKeyvault '../modules/keyvault.bicep' = {
  scope: coreResourceGroup
  params: {
    location: location
    namePrefix: '${namePrefix}-${location}'
  }
}

@description('Core storage account for diagnostics, artifacts, or shared blob data.')
module coreStorage '../modules/storage.bicep' = {
  scope: coreResourceGroup
  params: {
    namePrefix: namePrefix
    storageSku: storageSku
    storageAccountName: '${namePrefix}${location}corestorage'
  }
}
