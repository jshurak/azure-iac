// Hub virtual network and subnets for the core landing zone.
// Subnet address prefixes are derived from the VNet CIDR via cidrSubnet().
metadata description = 'Hub virtual network and dedicated subnets for the core landing zone.'

@description('Azure region for the hub virtual network.')
param location string

@description('Prefix used in resource names (e.g. js-hub-vnet).')
param namePrefix string

@description('Base IPv4 address for the virtual network (without suffix).')
param ipAddressSpace string

@description('CIDR suffix for the VNet, including leading slash (e.g. /16).')
param CIDR string

@description('Name of the hub virtual network.')
param networkName string 

@description('Subnets to create. Keys are subnet names; values are prefix lengths (newCIDR) passed to cidrSubnet().')
param subnets object 

@description('Full VNet address space in CIDR notation (for example, 10.0.0.0/16).')
var vnetAddressPrefix = '${ipAddressSpace}${CIDR}'

@description('creates a default network name if one is not provided..')
var vNetworkName = !empty(networkName) ? networkName : '${namePrefix}-${location}-vnet'


@description('Hub virtual network from Azure Verified Modules (AVM).')
module spokeNetwork 'br/public:avm/res/network/virtual-network:0.9.0' = {
  params: {
    name: vNetworkName
    location: location
    addressPrefixes: [
      vnetAddressPrefix
    ]
    // items(subnets) yields { key, value } per entry; loop index i is the cidrSubnet subnetIndex (0..n-1).
    subnets: [for (subnet, i) in items(subnets): {
      name: '${subnet.key}-subnet'
      addressPrefix: cidrSubnet(vnetAddressPrefix, int(subnet.value), i)
      privateEndpointNetworkPolicies: 'Enabled'
    }]
  }
}


@description('ARM resource IDs of subnets created in the hub virtual network.')
output subnetIDs array = spokeNetwork.outputs.subnetResourceIds

@description('Names of subnets created in the hub virtual network.')
output subnetNames array = spokeNetwork.outputs.subnetNames

@description('Full ARM resource ID of the deployed hub virtual network.')
output spokeNetworkResourceID string = spokeNetwork.outputs.resourceId

@description('Name of the deployed spoke virtual network.')
output spokeNetworkName string = spokeNetwork.outputs.name
