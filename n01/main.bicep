targetScope = 'subscription'
param namePrefix string
param location string 
param CIDR string 
param ipAddressSpace string
param networkName string
param subnets object
param privateDNSZoneName string
param globalResourceGroup string
param hubNetworkName string
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

//grab our hub network resource
@description('hub network resource for our production environment.')
resource hubNetwork 'Microsoft.Network/virtualNetworks@2024-06-01' existing = {
  scope: resourceGroup(globalResourceGroup)
  name: hubNetworkName
}

//need to grab our existing private dns zone from the core resource group
@description('private dns zone for our production environment.')
resource privateDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(globalResourceGroup)
  name: privateDNSZoneName
}

//child of private dns, so needs to reside in same resource group as private dns
module hubNetworkLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = {
  scope: resourceGroup(globalResourceGroup)
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


//create peering between hub and spoke
module spokePeering 'br/public:avm/res/network/virtual-network/virtual-network-peering:0.2.0' = {
  scope: coreResourceGroup
  params: {
    name: '${spokeNetwork.name}-to-${hubNetwork.name}-peering'
    localVnetName: spokeNetwork.name
    remoteVirtualNetworkResourceId: hubNetwork.id
  }
}
