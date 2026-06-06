metadata description = 'Creates a peering between a hub and a spoke virtual networks.'


param hubNetworkName string
param spokeNetworkNames object

param hubResourceGroup string


resource hubNetwork 'Microsoft.Network/virtualNetworks@2024-06-01' existing = {
  scope: resourceGroup(hubResourceGroup)
  name: hubNetworkName
}

resource spokeNetwork 'Microsoft.Network/virtualNetworks@2024-06-01' existing = {
  scope: resourceGroup(spokeResourceGroup)
  name: spokeNetworkName
}
