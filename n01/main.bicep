targetScope = 'subscription'
param namePrefix string
param location string 
param CIDR string 
param ipAddressSpace string
param networkName string
param subnets object
param privateDNSZoneName string
param globalResourceGroup string

param ownerName string

@description('Resource group that hosts core landing-zone networking, secrets, and storage.')
resource coreResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${namePrefix}-core-${location}-rg'
  location: location
}

module spokeNetwork '../modules/networkspoke.bicep' = {
  scope: coreResourceGroup
  params: {
    location: location
    CIDR: CIDR
    ipAddressSpace: ipAddressSpace
    namePrefix: namePrefix
    networkName: networkName
    subnets: subnets
  }
}


@description('private dns zone for our production environment.')
resource privateDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(globalResourceGroup)
  name: privateDNSZoneName
}

module hubNetworkLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = {
  scope: coreResourceGroup
  params: {
    name: '${networkName}-dns-link'
    privateDnsZoneName: privateDNSZone.name
    virtualNetworkResourceId: spokeNetwork.outputs.spokeNetworkResourceID
    location: 'global'
    registrationEnabled: true
    tags: {
      Environment: 'Prod'
      Owner: ownerName
    }
  }
}
