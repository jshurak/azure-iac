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
param storagesku string = 'Standard_LRS'

@description('Name of the Flex Consumption function app.')
param functionAppName string

//param subNets object = {
//}




//any existing resources that we need for this.  In this case, we need a private dns zone.
@description('Private dns zone for our production environment.')
resource privateDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(dnsResourceGroupName)
  name: 'js-company.com'
}

@description('Resource group that hosts the workload.')
resource wlResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${namePrefix}-${location}-rg'
  location: location
}

//start network buildout
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
  }
}


module peSubnet 'br/public:avm/res/network/virtual-network/subnet:0.2.0' = {
  scope: wlResourceGroup
  params: {
    name: 'PrivateEndpointSubnet'
    virtualNetworkName: wlNetwork.outputs.NetworkName
    addressPrefix: '10.2.1.0/24'
  }
}

module fnSubnet 'br/public:avm/res/network/virtual-network/subnet:0.2.0' = {
  scope: wlResourceGroup
  params: {
    name: 'FunctionAppSubnet'
    virtualNetworkName: wlNetwork.outputs.NetworkName
    addressPrefix: '10.2.2.0/24'
    delegation: 'Microsoft.App/environments'
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
  dependsOn: [
    wlNetwork
  ]
}
//end network buildout

//start identity buildout
module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.5.1' = {
  scope: wlResourceGroup
  params: {
    name: '${namePrefix}-identity'
  }
}
//end identity buildout

//build storage account and grant rbac permission to the identity
module storage '../modules/storage.bicep' = {
  scope: wlResourceGroup
  params: {
    storageAccountName: '${namePrefix}st${uniqueString(wlResourceGroup.id)}'
    storageSku: storagesku
    containerNames: ['${namePrefix}-app-container']
    blobPublicAccess: false
    roleAssignments: [
      {
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }
      {
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Blob Data Owner'
      }
      {
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Table Data Contributor'
      }
      {
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Queue Data Contributor'
      }
    ]
  }
}
//private endpoint for the storage
module blobPrivateEndpoint '../modules/privateendpoints.bicep' = {
  scope: wlResourceGroup
  params: {
    privateDnsZoneResourceId: privateDNSZone.id
    privateEndpointName: '${namePrefix}-storage-pe'
    serviceID: storage.outputs.resStorageID
    subnetResourceID: peSubnet.outputs.resourceId
    groupIds: ['blob']
  }
}
module queuePrivateEndpoint '../modules/privateendpoints.bicep' = {
  scope: wlResourceGroup
  params: {
    privateDnsZoneResourceId: privateDNSZone.id
    privateEndpointName: '${namePrefix}-storage-pe'
    serviceID: storage.outputs.resStorageID
    subnetResourceID: peSubnet.outputs.resourceId
    groupIds: ['queue']
  }
}
module tablePrivateEndpoint '../modules/privateendpoints.bicep' = {
  scope: wlResourceGroup
  params: {
    privateDnsZoneResourceId: privateDNSZone.id
    privateEndpointName: '${namePrefix}-storage-pe'
    serviceID: storage.outputs.resStorageID
    subnetResourceID: peSubnet.outputs.resourceId
    groupIds: ['table']
  }
}
//end storage account buildout


//build app insight and log analytics workspace
module appInsight '../modules/appinsight.bicep' = {
  scope: wlResourceGroup
  params: {
    namePrefix: namePrefix
    appInsightsName: '${namePrefix}-appinsights'
  }
}
//end app insight and log analytics workspace buildout



//build the app service and Function App

@description('Flex Consumption App Service plan for the function app.')
module appPlan '../modules/appserviceplan.bicep' = {
  scope: wlResourceGroup
  params: {
    appServicePlanName: '${namePrefix}-appservice-plan'
  }
}

@description('Python Flex Consumption function app with identity-based deployment storage.')
module functionApp '../modules/functionapp.bicep' = {
  scope: wlResourceGroup
  params: {
    functionAppName: functionAppName
    virtualNetworkSubnetResourceId: fnSubnet.outputs.resourceId
    storageAccountResourceID: storage.outputs.resStorageID
    storageAccountName: storage.outputs.resStorageName
    userAssignedIdentityClientID: identity.outputs.clientId
    blobContainerURL: storage.outputs.blobContainerURL
    serverFarmResourceID: appPlan.outputs.appServicePlanResourceID
    userAssignedResourceID: identity.outputs.resourceId
    appInsightInstrumentationKey: appInsight.outputs.appInsightInstrumentationKey
  }
}


//private endpoint for the storage
module appPrivateEndpoint '../modules/privateendpoints.bicep' = {
  scope: wlResourceGroup
  params: {
    privateDnsZoneResourceId: privateDNSZone.id
    privateEndpointName: '${namePrefix}-${functionApp.name}-pe'
    serviceID: functionApp.outputs.resourceId
    subnetResourceID: peSubnet.outputs.resourceId
    groupIds: ['sites']
  }
}
//end storage account buildout
