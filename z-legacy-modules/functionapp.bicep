metadata description = 'Linux Flex Consumption function app with blob deployment storage and user-assigned identity.'

@description('Explicit function app name. When empty, a name is generated from namePrefix and the resource group id.')
param functionAppName string = ''

@description('Prefix used when generating the function app name (for example, fna).')
param namePrefix string = 'wl01'

@description('Full ARM resource ID of the App Service plan (Flex Consumption, FC1).')
param serverFarmResourceID string

@description('Blob container URL used for deployment storage (account endpoint plus container name).')
param blobContainerURL string

@description('Full ARM resource ID of the user-assigned managed identity used for deployment storage and app identity.')
param userAssignedResourceID string

@description('When true, enables a system-assigned managed identity on the function app in addition to any user-assigned identities.')
param isSystemAssigned bool = false

@description('Name of the storage account.')
param storageAccountName string

@description('Full ARM resource ID of the storage account used for AzureWebJobsStorage configuration.')
param storageAccountResourceID string = ''

@description('Client ID of the user-assigned managed identity.')
param userAssignedIdentityClientID string = ''

@description('Instrumentation key of the deployed App Insights.')
param appInsightInstrumentationKey string = ''

@description('Full ARM resource ID of the virtual network to deploy the function app into.')
param virtualNetworkSubnetResourceId string

@description('Runtime name for the function app.  Python is the default.')
param runTimeName string = 'python'

@description('Runtime version for the function app.  Python 3.13 is the default.')
param runTimeVersion string = '3.13'

@description('Maximum instance count for the function app.  2 is the default.')
param maximumInstanceCount int = 2

@allowed([
  512
  2048
  4096
  ])
@description('Instance memory for the function app.  512 is the default.')
param instanceMemoryMB int = 512

@allowed([
  'Disabled'
  'Enabled'
])
@description('Public network access for the function app.  True to allow public access, false to restrict access to the virtual network.')
param publicNetworkAccess string = 'Disabled'


@description('Always on for the function app.  True to keep the function app running, false to allow it to sleep.')
param alwaysOn bool = false


var vFunctionAppName = !empty(functionAppName) ? functionAppName : '${namePrefix}-${uniqueString(resourceGroup().id)}'


@description('Flex Consumption function app deployed via Azure Verified Modules.')
module functionApp 'br/public:avm/res/web/site:0.23.1' = {
  params: {
    name: vFunctionAppName
    kind: 'functionapp'
    serverFarmResourceId: serverFarmResourceID
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
        name: runTimeName
        version: runTimeVersion
      }
      scaleAndConcurrency: {
        maximumInstanceCount: maximumInstanceCount
        instanceMemoryMB: instanceMemoryMB
      }
    }
    managedIdentities: {
      systemAssigned: isSystemAssigned
      userAssignedResourceIds: [
        userAssignedResourceID
      ]
    }
    publicNetworkAccess: publicNetworkAccess
    siteConfig: {
      alwaysOn: alwaysOn
    }
    virtualNetworkSubnetResourceId: virtualNetworkSubnetResourceId
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


@description('Full ARM resource ID of the deployed function app.')
output resourceId string = functionApp.outputs.resourceId
