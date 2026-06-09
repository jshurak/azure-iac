//  virtual network and subnets for the core landing zone.
// Subnet address prefixes are derived from the VNet CIDR via cidrSubnet().
metadata description = 'virtual network and dedicated subnets for the core landing zone.'

@description('Azure region for the  virtual network.')
param location string

@description('Prefix used in resource names (e.g. js--vnet).')
param namePrefix string

@description('Base IPv4 address for the virtual network (without suffix).')
param ipAddressSpace string

@description('CIDR suffix for the VNet, including leading slash (e.g. /16).')
param CIDR string

@description('Name of the virtual network.')
param networkName string 

@allowed([
  'hub'
  'spoke'
])
@description('Type of virtual network. This will determine the appropraite subnets to create.')
param networkType string 

@description('Any user requested subnets.  These should be provided as a key value pair of subnet name and prefix length.')
param subnets object = {}


@description('Default subnet layouts by network type. Keys are subnet names; values are prefix lengths passed to cidrSubnet().')
var subnetDefaults = {
  hub: {
    GatewaySubnet: '26'
    AzureFirewallSubnet: '26'
    AzureFirewallManagementSubnet: '26'
    AzureBastionSubnet: '26'
  }
  spoke: {
    
  }
}

//this joins the default subnets with and subnets that are sent with the subnets parameter
var vDefaultSubnets = subnetDefaults[networkType]
var vAllSubnets = union(vDefaultSubnets, subnets)




@description('Full VNet address space in CIDR notation (for example, 10.0.0.0/16).')
var vnetAddressPrefix = '${ipAddressSpace}${CIDR}'

//if a networkName is provided, use it, otherwise use the namePrefix
var vNetworkName = !empty(networkName) ? networkName : '${namePrefix}-vnet'

//This creates the virtual network with the name, location, address prefixes, and subnets
//loops through the vAllSubnets object to create subnets.  Calculates addressPrefix using the cidrSubnet function.
//sets privateEndpointNetworkPolicies to Enabled.  Needs to be enabled to use UDRs/NSGs on private endpoints.
@description(' virtual network from Azure Verified Modules (AVM).')
module Network 'br/public:avm/res/network/virtual-network:0.9.0' = {
  params: {
    name: vNetworkName
    location: location
    addressPrefixes: [
      vnetAddressPrefix
    ]
    // items(subnets) yields { key, value } per entry; loop index i is the cidrSubnet subnetIndex (0..n-1).
    subnets: [for (subnet, i) in items(vAllSubnets): {
      name: subnet.key
      addressPrefix: cidrSubnet(vnetAddressPrefix, int(subnet.value), i)
      privateEndpointNetworkPolicies: 'Enabled'
    }]
  }
}


//this outputs the subnet resource IDs, names, and the full resource ID of the deployed virtual network.

@description('ARM resource IDs of subnets created in the  virtual network.')
output subnetIDs array = Network.outputs.subnetResourceIds

@description('Names of subnets created in the  virtual network.')
output subnetNames array = Network.outputs.subnetNames


@description('Full ARM resource ID of the deployed  virtual network.')
output NetworkResourceID string = Network.outputs.resourceId

@description('Name of the deployed  virtual network.')
output NetworkName string = Network.outputs.name
