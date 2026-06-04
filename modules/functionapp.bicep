param functionAppName string = ''
param namePrefix string = 'fna'
param serverFarmResourceID string
param blobContainerURL string
param userAssignedResourceID string
param isSystemAssigned bool = false

var vFunctionAppName = !empty(functionAppName) ? functionAppName : '${namePrefix}-${uniqueString(resourceGroup().id)}'

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
        name: 'python'
        version: '3.13'
      }
      scaleAndConcurrency: {
        maximumInstanceCount:2
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
  }
}
