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

@description('Owner name applied as a tag on deployed resources (for example, a team or individual).')
param ownerName string

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
    location: location
    namePrefix: namePrefix
    CIDR: CIDR
    ipAddressSpace: ipAddressSpace
  }
}


/*
@description('Hub virtual network with Firewall, Gateway, and Bastion subnets.')
module coreVNet '../modules/virtualnetwork.bicep' = {
  scope: coreResourceGroup
  params:{
    networkType: 'hub'
    networkName: networkName
    location: location
    CIDR: CIDR
    ipAddressSpace: ipAddressSpace 
    namePrefix: namePrefix
  }
}


@description('Private dns zone for our production environment.')
module customPrivateDNSZone 'br/public:avm/res/network/private-dns-zone:0.8.1' = {
  scope: coreResourceGroup
  params: {
    name: '${namePrefix}-company.com'
    location: 'global'
    tags: {
      Environment: 'Prod'
      Owner: ownerName
      
    }
  }
}
@description('Private dns zone for our production environment.')
module websitesDNSZone 'br/public:avm/res/network/private-dns-zone:0.8.1' = {
  scope: coreResourceGroup
  params: {
    name: 'privatelink.AzureWebSites.net'
    location: 'global'
    tags: {
      Environment: 'Prod'
      Owner: ownerName
      
    }
  }
}



module hubCustomDNSNetworkLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = {
  scope: coreResourceGroup
  params: {
    name: '${networkName}-dns-link'
    privateDnsZoneName: customPrivateDNSZone.outputs.name
    virtualNetworkResourceId: coreVNet.outputs.NetworkResourceID
    location: 'global'
    registrationEnabled: true
    tags: {
      Environment: 'Prod'
      Owner: ownerName
    }
  }
}

module hubWbesiteDNSNetworkLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = {
  scope: coreResourceGroup
  params: {
    name: '${networkName}-websites-dns-link'
    privateDnsZoneName: websitesDNSZone.outputs.name
    virtualNetworkResourceId: coreVNet.outputs.NetworkResourceID
    location: 'global'
    registrationEnabled: false
    tags: {
      Environment: 'Prod'
      Owner: ownerName
    }
  }
}
*/

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
