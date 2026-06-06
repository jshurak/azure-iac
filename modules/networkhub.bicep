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
param subnets object = {
  Firewall: '26'
  Gateway: '26'
  Bastion: '26'
  PrivateLink: '24'
}

@description('Full VNet address space in CIDR notation (for example, 10.0.0.0/16).')
var vnetAddressPrefix = '${ipAddressSpace}${CIDR}'


var vNetworkName = !empty(networkName) ? networkName : '${namePrefix}-hub-vnet'


@description('Hub virtual network from Azure Verified Modules (AVM).')
module hubNetwork 'br/public:avm/res/network/virtual-network:0.9.0' = {
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
    }]
  }
}


@description('ARM resource IDs of subnets created in the hub virtual network.')
output subnetIDs array = hubNetwork.outputs.subnetResourceIds

@description('Names of subnets created in the hub virtual network.')
output subnetNames array = hubNetwork.outputs.subnetNames


@description('Full ARM resource ID of the deployed hub virtual network.')
output hubNetworkResourceID string = hubNetwork.outputs.resourceId
