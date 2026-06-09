targetScope = 'resourceGroup'

@description('Name of the resource group that hosts the hub network.')
param resourceGroupName string

@description('Name of the hub virtual network.')
param networkName string

@description('Prefix used in resource names (for example, js).')
param namePrefix string

@description('CIDR suffix for the VNet, including the leading slash (for example, /16).')
param CIDR string

@description('Base IPv4 address for the virtual network (without suffix).')
param ipAddressSpace string

@description('Company domain for the private DNS zone.')
param companyDomain string

@description('Additional subnets to create beyond the default hub layout (subnet name to prefix length).')
param subnets object = {
  workload: '24'
}

@description('Resource group that hosts the remote hub virtual network for peering.')
param hubResourceGroupName string

@description('Name of the remote hub virtual network to peer with.')
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
module coreVNet 'br/JSRegistry:network/virtual-network:v1.0.0' = {
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
module peering 'br/JSRegistry:network/peering:v1.0.0' = {
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


@description('Existing company private DNS zone in the remote hub resource group.')
resource privateDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(hubResourceGroupName)
  name: companyDomain
}

@description('Links the hub VNet to the existing company private DNS zone for auto-registration.')
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


output subnetIDs array = coreVNet.outputs.subnetIDs
