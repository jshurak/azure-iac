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

//Function apps require blob/queue/table contributor roles.  In order to keep this solution off the 
//public internet, well will create dns zones and private endpoints for blob, queue, and table services.
//as they are global resources, we will create them in our main hub.
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
  scope: az.resourceGroup(resourceGroupName)
  params: {
    networkType: 'hub'
    networkName: networkName
    location: resourceGroup().location
    CIDR: CIDR
    ipAddressSpace: ipAddressSpace
    namePrefix: namePrefix
    subnets: subnets
  }
}

@description('Private dns zone for our production environment.')
module customPrivateDNSZone 'br/public:avm/res/network/private-dns-zone:0.8.1' = {
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: companyDomain
    location: 'global'
  }
}

@description('Private dns zone for our production environment.')
module websitesDNSZone 'br/public:avm/res/network/private-dns-zone:0.8.1' = {
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: 'privatelink.AzureWebSites.net'
    location: 'global'
  }
}


@description('Links the hub VNet to the company private DNS zone for auto-registration.')
module hubCustomDNSNetworkLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = {
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: '${networkName}-dns-link'
    privateDnsZoneName: customPrivateDNSZone.outputs.name
    virtualNetworkResourceId: coreVNet.outputs.NetworkResourceID
    location: 'global'
    registrationEnabled: true
  }
}

@description('Links the hub VNet to the Azure Websites private DNS zone.')
module hubWbesiteDNSNetworkLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = {
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: '${networkName}-websites-dns-link'
    privateDnsZoneName: websitesDNSZone.outputs.name
    virtualNetworkResourceId: coreVNet.outputs.NetworkResourceID
    location: 'global'
    registrationEnabled: false
  }
}



@description('Private DNS zones for storage private link endpoints.')
module storagePrivateDNSZone 'br/public:avm/res/network/private-dns-zone:0.8.1' = [
  for endpoint in storageEndpoints: {
    scope: az.resourceGroup(resourceGroupName)
    params: {
      name: 'privatelink.${endpoint}.core.windows.net'
      location: 'global'
      virtualNetworkLinks: [
        {
          name: '${networkName}-${endpoint}-dns-link'
          virtualNetworkResourceId: coreVNet.outputs.NetworkResourceID
        }
      ]
    }
  }
]

/*
@description('Links the spoke VNet to the existing private DNS zone for auto-registration.')
module storageDNSink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = [
  for (endpoint, i) in storageEndpoints: {
    scope: az.resourceGroup(resourceGroupName)
    params: {
      name: '${networkName}-dns-link'
      privateDnsZoneName: storagePrivateDNSZone[i].outputs.name
      virtualNetworkResourceId: coreVNet.outputs.NetworkResourceID
      location: 'global'
      registrationEnabled: false
    }
  }
]
*/
