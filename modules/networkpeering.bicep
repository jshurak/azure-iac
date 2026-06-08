targetScope = 'subscription'
metadata description = 'Creates a peering between a net1 and a net2 virtual network. requires both networks to exist.'

@description('Resource group name containing the first (local) virtual network.')
param net1ResourceGroup string

@description('Name of the first virtual network to peer.')
param net1NetworkName string

@description('Resource group name containing the second (remote) virtual network.')
param net2ResourceGroup string

@description('Name of the second virtual network to peer.')
param net2NetworkName string

@description('When true, allows gateway transit on the peering from net1 to net2.')
param allowGatewayTransit bool = false

resource net1Network 'Microsoft.Network/virtualNetworks@2025-05-01' existing = {
  scope: resourceGroup(net1ResourceGroup)
  name: net1NetworkName
}

resource net2Network 'Microsoft.Network/virtualNetworks@2025-05-01' existing = {
  scope: resourceGroup(net2ResourceGroup)
  name: net2NetworkName
}

module net1ToNet2Peering 'br/public:avm/res/network/virtual-network/virtual-network-peering:0.2.0' = {
  scope: resourceGroup(net1ResourceGroup)
  params: {
    name: '${net1NetworkName}-to-${net2NetworkName}-peering'
    localVnetName: net1NetworkName
    remoteVirtualNetworkResourceId: net2Network.id
    allowGatewayTransit: allowGatewayTransit
  }
}

module net2ToNet1Peering 'br/public:avm/res/network/virtual-network/virtual-network-peering:0.2.0' = {
  scope: resourceGroup(net2ResourceGroup)
  params: {
    name: '${net2NetworkName}-to-${net1NetworkName}-peering'
    localVnetName: net2NetworkName
    remoteVirtualNetworkResourceId: net1Network.id
  }
}
