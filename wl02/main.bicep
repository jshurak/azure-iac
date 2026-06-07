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

//@description('Name of the Flex Consumption function app.')
//param functionAppName string

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
module privateEndpoint '../modules/privateendpoints.bicep' = {
  scope: wlResourceGroup
  params: {
    serviceID: storage.outputs.resStorageID
    subnetResourceID: wlNetwork.outputs.subnetIDs[0]
    groupIds: ['blob']
  }
}
//end storage account buildout


//build app insight and log analytics workspace
module appInsight '../modules/appinsight.bicep' = {
  scope: wlResourceGroup
  params: {
    appInsightsName: '${namePrefix}-appinsights'
  }
}
//end app insight and log analytics workspace buildout

/*

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
    storageAccountResourceID: storage.outputs.resStorageID
    storageAccountName: storage.outputs.resStorageName
    userAssignedIdentityClientID: identity.outputs.clientId
    blobContainerURL: storage.outputs.blobContainerURL
    serverFarmResourceID: appPlan.outputs.appServicePlanResourceID
    userAssignedResourceID: identity.outputs.resourceId
    appInsightInstrumentationKey: appInsight.outputs.appInsightInstrumentationKey
  }
}
//build the app service and Function App
*/
