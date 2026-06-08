param namePrefix string
param functionAppName string
param virtualNetworkSubnetResourceId string
param storageAccountResourceID string
param storageAccountName string
param userAssignedIdentityClientID string
param blobContainerURL string
param userAssignedResourceID string
param appInsightInstrumentationKey string
param functionAppPrivateDnsZoneResourceId string

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
    virtualNetworkSubnetResourceId: virtualNetworkSubnetResourceId
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
    subnetResourceID: virtualNetworkSubnetResourceId
    groupIds: ['sites']
  }
}
