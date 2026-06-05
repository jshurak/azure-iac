metadata description = 'Linux Flex Consumption function app with blob deployment storage and user-assigned identity.'

@description('Explicit function app name. When empty, a name is generated from namePrefix and the resource group id.')
param functionAppName string = ''

@description('Prefix used when generating the function app name (for example, fna).')
param namePrefix string = 'wl01'

//@description('Full ARM resource ID of the App Service plan (Flex Consumption, FC1).')
//param serverFarmResourceID string

@description('Blob container URL used for deployment storage (account endpoint plus container name).')
param blobContainerURL string

@description('Full ARM resource ID of the user-assigned managed identity used for deployment storage and app identity.')
param userAssignedResourceID string

@description('When true, enables a system-assigned managed identity on the function app in addition to any user-assigned identities.')
param isSystemAssigned bool = false

@description('Name of the storage account.')
param storageAccountName string

param storageAccountResourceID string = ''

@description('Client ID of the user-assigned managed identity.')
param userAssignedIdentityClientID string = ''

@description('Instrumentation key of the deployed App Insights.')
param appInsightInstrumentationKey string = ''


var vFunctionAppName = !empty(functionAppName) ? functionAppName : '${namePrefix}-${uniqueString(resourceGroup().id)}'




resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name:  '${namePrefix}-appservice-plan'
  location: resourceGroup().location
  kind: 'functionapp'
  sku: {
    tier: 'FlexConsumption'
    name: 'FC1'
  }
  properties: {
    reserved: true
  }
}





@description('Flex Consumption function app (Python 3.13) deployed via Azure Verified Modules.')
module functionApp 'br/public:avm/res/web/site:0.23.1' = {
  params: {
    name: vFunctionAppName
    kind: 'functionapp'
    serverFarmResourceId: appServicePlan.id
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: blobContainerURL
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: userAssignedResourceID
          }
        }
      }
      runtime: {
        name: 'python'
        version: '3.13'
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 2
        instanceMemoryMB: 512
      }
    }
    managedIdentities: {
      systemAssigned: isSystemAssigned
      userAssignedResourceIds: [
        userAssignedResourceID
      ]
    }
    siteConfig: {
      alwaysOn: false
    }
    configs: [
      {
        name: 'appsettings'
        storageAccountResourceId: storageAccountResourceID // add this param
        storageAccountUseIdentityAuthentication: true
        properties: {
          AzureWebJobsStorage__accountName: storageAccountName
          AzureWebJobsStorage__credential: 'managedidentity'
          AzureWebJobsStorage__clientId: userAssignedIdentityClientID
          APPINSIGHTS_INSTRUMENTATIONKEY: appInsightInstrumentationKey
          APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'ClientId=${userAssignedIdentityClientID};Authorization=AAD'
        }
      }
    ]
  }
}
