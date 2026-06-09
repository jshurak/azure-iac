@description('Prefix used in resource names (for example, wl01).')
param namePrefix string

@description('Name of the Flex Consumption function app.')
param functionAppName string

@description('Full ARM resource ID of the subnet used for function app VNet integration outbound traffic.')
param OutbountVirtualNetworkSubnetResourceId string

@description('Full ARM resource ID of the storage account used for AzureWebJobsStorage configuration.')
param storageAccountResourceID string

@description('Name of the storage account.')
param storageAccountName string

@description('Client ID of the user-assigned managed identity.')
param userAssignedIdentityClientID string

@description('Blob container URL used for deployment storage (account endpoint plus container name).')
param blobContainerURL string

@description('Full ARM resource ID of the user-assigned managed identity used for deployment storage and app identity.')
param userAssignedResourceID string

@description('Instrumentation key of the deployed App Insights.')
param appInsightInstrumentationKey string

@description('Full ARM resource ID of the private DNS zone for the function app private endpoint.')
param functionAppPrivateDnsZoneResourceId string

@description('Full ARM resource ID of the subnet that hosts the function app private endpoint.')
param PrivateEndPointSubnetResourceId string

var localResourceGroup = az.resourceGroup()


@description('Flex Consumption App Service plan for the function app.')
module appPlan '../../modules/appserviceplan.bicep' = {
  scope: localResourceGroup
  params: {
    appServicePlanName: '${namePrefix}-appservice-plan'
  }
}

@description('Python Flex Consumption function app with identity-based deployment storage.')
module functionApp '../../modules/functionapp.bicep' = {
  scope: localResourceGroup
  params: {
    functionAppName: functionAppName
    virtualNetworkSubnetResourceId: OutbountVirtualNetworkSubnetResourceId
    storageAccountResourceID: storageAccountResourceID
    storageAccountName: storageAccountName
    userAssignedIdentityClientID: userAssignedIdentityClientID
    blobContainerURL: blobContainerURL
    serverFarmResourceID: appPlan.outputs.appServicePlanResourceID
    userAssignedResourceID: userAssignedResourceID
    appInsightInstrumentationKey: appInsightInstrumentationKey
  }
}

@description('Private endpoint for inbound access to the function app.')
module appPrivateEndpoint '../../modules/privateendpoints.bicep' = {
  scope: localResourceGroup
  params: {
    privateDnsZoneResourceId: functionAppPrivateDnsZoneResourceId
    privateEndpointName: '${namePrefix}-${functionApp.name}-pe'
    serviceID: functionApp.outputs.resourceId
    subnetResourceID: PrivateEndPointSubnetResourceId
    groupIds: ['sites']
  }
}
