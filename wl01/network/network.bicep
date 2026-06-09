targetScope = 'resourceGroup'

@description('Name of the resource group that hosts the workload network.')
param resourceGroupName string

@description('Name of the spoke virtual network for this workload.')
param networkName string

@description('Prefix used in resource names (for example, wl01).')
param namePrefix string

@description('CIDR suffix for the VNet, including the leading slash (for example, /20).')
param CIDR string

@description('Base IPv4 address for the virtual network (without suffix).')
param ipAddressSpace string

@description('Company domain for the private DNS zone.')
param companyDomain string

@description('Resource group that hosts the private DNS zone used for VNet registration.')
param dnsResourceGroupName string

@description('Resource group that hosts the hub virtual network.')
param hubResourceGroupName string

@description('Name of the hub virtual network to peer with.')
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


//any existing resources that we need for this.  
//In this case, we need a private dns zone to set registration for the workload vNet.
@description('Private dns zone for our production environment.')
resource privateDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(dnsResourceGroupName)
  name: companyDomain
}


//start network buildout
@description('Virtual network and subnets for the workload.')
module wlNetwork 'br/JSRegistry:network/virtual-network:v1.0.0' = {
  scope: localResrourceGroup
  params: {
    networkName: networkName
    location: az.resourceGroup().location
    CIDR: CIDR
    ipAddressSpace: ipAddressSpace
    namePrefix: namePrefix
    networkType: 'spoke'
  }
}

@description('Subnet reserved for private endpoints.')
module peSubnet 'br/public:avm/res/network/virtual-network/subnet:0.2.0' = {
  scope: localResrourceGroup
  params: {
    name: 'PrivateEndpointSubnet'
    virtualNetworkName: wlNetwork.outputs.NetworkName
    addressPrefix: '10.2.1.0/24'
  }
}

@description('Subnet delegated to Azure Functions Flex Consumption.')
module fnSubnet 'br/public:avm/res/network/virtual-network/subnet:0.2.0' = {
  scope: localResrourceGroup
  params: {
    name: 'FunctionAppSubnet'
    virtualNetworkName: wlNetwork.outputs.NetworkName
    addressPrefix: '10.2.2.0/24'
    delegation: 'Microsoft.App/environments'
  }
  dependsOn: [
    peSubnet
  ]
}



@description('Links the spoke VNet to the existing private DNS zone for auto-registration.')
module hubNetworkLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = {
  scope: resourceGroup(dnsResourceGroupName)
  params: {
    name: '${networkName}-dns-link'
    privateDnsZoneName: privateDNSZone.name
    virtualNetworkResourceId: wlNetwork.outputs.NetworkResourceID
    location: 'global'
    registrationEnabled: true
  }
}


@description('Bidirectional peering between the hub and spoke virtual networks.')
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
    wlNetwork
  ]
}

@description('Existing storage private link DNS zones in the hub resource group.')
resource storagePrivateDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = [
  for endpoint in storageEndpoints: {
    scope: resourceGroup(dnsResourceGroupName)
    name: 'privatelink.${endpoint}.core.windows.net'
  }
]

@description('Links this VNet to existing storage private DNS zones for private endpoint name resolution.')
module storageDNSLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = [
  for (endpoint, i) in storageEndpoints: {
    scope: resourceGroup(dnsResourceGroupName)
    params: {
      name: '${networkName}-${endpoint}-dns-link'
      privateDnsZoneName: storagePrivateDNSZone[i].name
      virtualNetworkResourceId: wlNetwork.outputs.NetworkResourceID
      location: 'global'
      registrationEnabled: false
    }
  }
]


@description('Private DNS zones for Function App private link endpoints.')
resource functionAppPrivateDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(dnsResourceGroupName)
  name: 'privatelink.AzureWebSites.net'
}

@description('Links the spoke VNet to the existing private DNS zone for auto-registration.')
module dnsNetworkLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = {
  scope: resourceGroup(dnsResourceGroupName)
  params: {
    name: '${networkName}-dns-link'
    privateDnsZoneName: functionAppPrivateDNSZone.name
    virtualNetworkResourceId: wlNetwork.outputs.NetworkResourceID
    location: 'global'
    registrationEnabled: false
  }
}



@description('Full ARM resource ID of the deployed spoke virtual network.')
output networkResourceId string = wlNetwork.outputs.NetworkResourceID

@description('ARM resource ID of the private endpoint subnet.')
output peSubnetResourceId string = peSubnet.outputs.resourceId

@description('ARM resource ID of the function app subnet.')
output fnSubnetResourceId string = fnSubnet.outputs.resourceId

@description('ARM resource IDs of existing storage private DNS zones.')
output storagePrivateDnsZoneResourceIds array = [for (endpoint, i) in storageEndpoints: storagePrivateDNSZone[i].id]

@description('ARM resource ID of the function app private DNS zone.')
output functionAppPrivateDnsZoneResourceId string = functionAppPrivateDNSZone.id
//end network buildout
