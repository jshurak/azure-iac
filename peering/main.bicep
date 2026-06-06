targetScope = 'subscription'
param hubResourceGroup string
param hubNetworkName string
param spokeNetworks object



@description('Creates a peering between the hub and each spoke network.')
module networkPeering '../modules/networkpeering.bicep' = [
  for spoke in items(spokeNetworks): {
    scope: subscription()
    params: {
      net1ResourceGroup: hubResourceGroup
      net1NetworkName: hubNetworkName
      net2ResourceGroup: spoke.key
      net2NetworkName: spoke.value
      isHubandSpoke: true
    }
  }
]
