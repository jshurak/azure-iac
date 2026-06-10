targetScope = 'subscription'
metadata description = 'Subscription-scoped landing zone: core resource group, hub network, Key Vault, and storage.'

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



//The resource group that we are going to host our core services
@description('Resource group that hosts core landing-zone networking, secrets, and storage.')
resource coreResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${namePrefix}-${location}-core-rg'
  location: location
}



//Deploy a core hub network that will host our global services.
@description('Hub virtual network, private DNS zones, and storage private link DNS for the landing zone.')
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



//Deploy a key vault that will host our secrets and certificates.
@description('Key Vault for secrets and certificates used by the landing zone.')
module coreKeyvault 'br/JSRegistry:key-vault:v1.0.0' = {
  scope: coreResourceGroup
  params: {
    location: location
    namePrefix: '${namePrefix}-${coreResourceGroup.location}'
  }
}

//Deploy a core storage account that will host our diagnostics, artifacts, and shared blob data.
@description('Core storage account for diagnostics, artifacts, or shared blob data.')
module coreStorage 'br/JSRegistry:storage/storage-account:v1.5.1' = {
  scope: coreResourceGroup
  params: {
    namePrefix: namePrefix
    storageSku: storageSku
    storageAccountName: '${namePrefix}${coreResourceGroup.location}corestorage'
  }
}
