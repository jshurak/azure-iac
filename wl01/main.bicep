metadata description = 'This workload deploys a function app with spoke networking, private endpoints, and identity-based storage access'
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

@description('Name of the hub virtual network to peer with.')
param hubNetworkName string

@description('Resource group that hosts the hub virtual network.')
param hubResourceGroupName string

@description('Name of the spoke virtual network for this workload.')
param networkName string = '${namePrefix}-vnet'

@description('Resource group that hosts the private DNS zone used for VNet registration.')
param dnsResourceGroupName string

@description('Prefix applied to workload resource names (for example, wl01-centralus-rg).')
param namePrefix string = 'wl01'

@description('Azure region for the workload resource group and deployed resources.')
param location string = 'centralus'


@description('Replication SKU for the workload storage account (LRS or zone-redundant ZRS).')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
])
param storagesku string = 'Standard_LRS'

//Function apps require blob/queue/table contributor roles.  In order to keep this solution off the 
//public internet, well will create dns zones and private endpoints for blob, queue, and table services.
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

@description('Name of the Flex Consumption function app.')
param functionAppName string = '${namePrefix}-function-app'

@description('Resource group that hosts the workload.')
resource wlResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${namePrefix}-${location}-rg'
  location: location
}

@description('Spoke virtual network with hub peering, private DNS zones, and subnets for function app and private endpoints.')
module wlNetwork './network/network.bicep' = {
  scope: wlResourceGroup
  params: {
    dnsResourceGroupName: dnsResourceGroupName
    hubResourceGroupName: hubResourceGroupName
    hubNetworkName: hubNetworkName
    networkName: networkName
    namePrefix: namePrefix
    CIDR: '/20'
    ipAddressSpace: '10.2.0.0'
    companyDomain: 'js-company.com'
    resourceGroupName: wlResourceGroup.name
    storageEndpoints: storageEndpoints
  }
}

@description('User-assigned managed identity with RBAC for function app storage access.')
module identity './identity/identity.bicep' = {
  scope: wlResourceGroup
  params: {
    namePrefix: namePrefix
  }
}

@description('Storage account, blob container, and private endpoints for function app deployment and triggers.')
module storage './storage/storage.bicep' = {
  scope: wlResourceGroup
  params: {
    namePrefix: namePrefix
    storagesku: storagesku
    storageEndpoints: storageEndpoints
    storagePrivateDnsZoneResourceIds: wlNetwork.outputs.storagePrivateDnsZoneResourceIds
    peSubnetResourceId: wlNetwork.outputs.peSubnetResourceId
    identityPrincipalId: identity.outputs.principalId
  }
}

@description('Application Insights and Log Analytics workspace for function app telemetry.')
module appInsight './insights/app-insights.bicep' = {
  scope: wlResourceGroup
  params: {
    namePrefix: namePrefix
  }
}

@description('Python Flex Consumption function app with VNet integration and private endpoint.')
module functionApp './compute/function-app.bicep' = {
  scope: wlResourceGroup
  params: {
    namePrefix: namePrefix
    functionAppName: functionAppName
    OutbountVirtualNetworkSubnetResourceId: wlNetwork.outputs.fnSubnetResourceId
    storageAccountResourceID: storage.outputs.resStorageID
    storageAccountName: storage.outputs.resStorageName
    userAssignedIdentityClientID: identity.outputs.clientId
    blobContainerURL: storage.outputs.blobContainerURL
    userAssignedResourceID: identity.outputs.resourceId
    appInsightInstrumentationKey: appInsight.outputs.appInsightInstrumentationKey
    functionAppPrivateDnsZoneResourceId: wlNetwork.outputs.functionAppPrivateDnsZoneResourceId
    PrivateEndPointSubnetResourceId: wlNetwork.outputs.peSubnetResourceId
  }
}
