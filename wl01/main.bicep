
targetScope = 'subscription'
metadata description = 'Creates an Azure function app on a Flex Consumption plan. required storage acccount as well as application insights.'

@description('Prefix applied to workload resource names (for example, wl01-rg, wl01stacc).')
param namePrefix string

@description('Replication SKU for the workload storage account (for example, Standard_LRS).')
param storagesku string

@description('Azure region for the workload resource group and deployed resources.')
param location string


@description('Name of the Flex Consumption function app.')
param functionAppName string

@description('Resource group that hosts the workload.')
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${namePrefix}-rg'
  location: location
}

@description('User-assigned managed identity for function app storage access.')
module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.5.1' = {
  scope: resourceGroup
  params: {
    name: '${namePrefix}-identity'
  }
}

@description('Storage account, blob container, and RBAC for the function app deployment and triggers.')
module storage '../modules/storage.bicep' = {
  scope: resourceGroup
  params: {
    storageAccountName: '${namePrefix}stacc'
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



@description('Flex Consumption App Service plan for the function app.')
module appPlan '../modules/appserviceplan.bicep' = {
  scope: resourceGroup
  params: {
    appServicePlanName: '${namePrefix}-appservice-plan'
  }
}




module appInsight '../modules/appinsight.bicep' = {
  scope: resourceGroup
  params: {
    namePrefix: namePrefix
    appInsightsName: '${namePrefix}-appinsights'
  }
}

@description('Python Flex Consumption function app with identity-based deployment storage.')
module functionApp '../modules/functionapp.bicep' = {
  scope: resourceGroup
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
