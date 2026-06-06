metadata description = 'This workload deploys an function app'
targetScope = 'subscription'

/*
For this workload, we will create the following
a resource group
a spoke network with peering between it's region's hub network
a user mmanaged identity and assign rolesto handle communication between the function app, storage account and app inights
it will leverage a private endpoint to communicate privately, with existing private dns zone
it will create the app insight and log analytics workspace
an app service plan
the python function app
*/

param hubNetworkName string
param hubResourceGroupName string
param networkName string
param dnsResourceGroupName string

param namePrefix string = 'wl02'
param location string = 'centralus'
param ownerName string = 'Jeff Shurak'


@description('Private dns zone for our production environment.')
resource privateDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(dnsResourceGroupName)
  name: '${namePrefix}-company.com'
}

@description('Resource group that hosts the workload.')
resource wlResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${namePrefix}-${location}-rg'
  location: location
}

@description('Virtual network and subnets for the workload.')
module wlNetwork '../modules/virtualnetwork.bicep' = {
  scope: wlResourceGroup
  params: {
    networkName: networkName
    location: location
    CIDR: '/20'
    ipAddressSpace: '10.2.0.0'
    namePrefix: namePrefix
    networkType: 'spoke'
    subnets: {
      workloadSubnet: '24'
    }
  }
}

module hubNetworkLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = {
  scope: resourceGroup(dnsResourceGroupName)
  params: {
    name: '${networkName}-dns-link'
    privateDnsZoneName: privateDNSZone.name
    virtualNetworkResourceId: wlNetwork.outputs.NetworkResourceID
    location: 'global'
    registrationEnabled: true
    tags: {
      Environment: 'Prod'
      Owner: ownerName
    }
  }
}

module peering '../modules/networkpeering.bicep' = {
  scope: subscription()
  params: {
    net1ResourceGroup: hubResourceGroupName
    net1NetworkName: hubNetworkName
    net2ResourceGroup: wlResourceGroup.name
    net2NetworkName: networkName
    allowGatewayTransit: false
  }
}
