targetScope = 'resourceGroup'

param resourceGroupName string
param networkName string
param namePrefix string
param CIDR string
param ipAddressSpace string
param companyDomain string
param subnets object = {
  workload: '24'
}

param hubResourceGroupName string
param hubNetworkName string

var localResrourceGroup = az.resourceGroup(resourceGroupName)

//Function apps require blob/queue/table contributor roles.  In order to keep this solution off the 
//public internet, well will create dns zones and private endpoints for blob, queue, and table services.
@description('Storage subresources to expose via private endpoints (blob, queue, table, file, or dfs).')
@allowed([
  'blob'
  'queue'
  'table'
])
param storageEndpoints array = [
  'blob'
  'queue'
  'table'
]


@description('Hub virtual network with Firewall, Gateway, and Bastion subnets.')
module coreVNet '../../modules/virtualnetwork.bicep' = {
  scope: localResrourceGroup
  params:{
    networkType: 'hub'
    networkName: networkName
    location: az.resourceGroup().location
    CIDR: CIDR
    ipAddressSpace: ipAddressSpace 
    namePrefix: namePrefix
    subnets: subnets
  }
}


@description('peering between central us hub and east us hub')
module peering '../../modules/networkpeering.bicep' = {
  scope: subscription()
  params: {
    net1ResourceGroup: hubResourceGroupName
    net1NetworkName: hubNetworkName
    net2ResourceGroup: resourceGroup().name
    net2NetworkName: networkName
    allowGatewayTransit: false
  }
  dependsOn: [
    coreVNet
  ]
}


resource privateDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(hubResourceGroupName)
  name: companyDomain
}

module hubNetworkLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = {
  scope: resourceGroup(hubResourceGroupName)
  params: {
    name: '${networkName}-dns-link'
    privateDnsZoneName: privateDNSZone.name
    virtualNetworkResourceId: coreVNet.outputs.NetworkResourceID
    location: 'global'
    registrationEnabled: true
  }
}

@description('Existing storage private link DNS zones in the hub resource group.')
resource storagePrivateDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = [
  for endpoint in storageEndpoints: {
    scope: resourceGroup(hubResourceGroupName)
    name: 'privatelink.${endpoint}.core.windows.net'
  }
]

@description('Links this VNet to existing storage private DNS zones for private endpoint name resolution.')
module storageDNSLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = [
  for (endpoint, i) in storageEndpoints: {
    scope: resourceGroup(hubResourceGroupName)
    params: {
      name: '${networkName}-${endpoint}-dns-link'
      privateDnsZoneName: storagePrivateDNSZone[i].name
      virtualNetworkResourceId: coreVNet.outputs.NetworkResourceID
      location: 'global'
      registrationEnabled: false
    }
  }
]
