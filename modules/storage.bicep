metadata description = 'Core storage account for shared blob data and artifacts.'

@description('Prefix used in the storage account name (for example, jscorestorage).')
param namePrefix string = 'sa'

@description('Storage account name')
param storageAccountName string = ''

@description('Azure Storage replication SKU (Standard_LRS or Standard_ZRS).')
param storageSku string

@description('The storage account type')
param storageKind string = 'StorageV2'

@description('Public access policy for blob.')
param blobPublicAccess bool = false

@allowed([
  'Enabled'
  'Disabled'
  'SecuredByPerimeter'
])
@description('Public access for storage account')
param publicNetworkAccess string = 'Disabled'

@allowed([
  'AzureServices'
  'None'
])
@description('ACL bypass for storage account')
param aclBypass string = 'None'

@allowed([
  'Allow'
  'Deny'
])
@description('Default action for ACL')
param aclDefaultAction string = 'Deny'

@description('Blob container names to create in the storage account.')
param containerNames string[] = []

@description('RBAC role assignments applied to the storage account (principalId, principalType, roleDefinitionIdOrName).')
param roleAssignments array = []

var vStorageAccountName = !empty(storageAccountName)
  ? storageAccountName
  : '${namePrefix}${uniqueString(resourceGroup().id)}'

// Bicep requires the loop body object on the same line as the for-expression colon.
var blobContainers = [
  for name in containerNames: {
    name: name
  }
]

@description('StorageV2 account with public blob access disabled.')
module resStorage 'br/public:avm/res/storage/storage-account:0.32.1' = {
  params: {
    name: vStorageAccountName
    allowBlobPublicAccess: blobPublicAccess
    kind: storageKind
    skuName: storageSku
    location: resourceGroup().location
    roleAssignments: roleAssignments
    allowSharedKeyAccess: true
    blobServices: !empty(containerNames)
      ? {
          containers: blobContainers
        }
      : null
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      bypass: aclBypass
      defaultAction: aclDefaultAction
    }
  }
}

@description('Name of the deployed storage account.')
output resStorageName string = resStorage.outputs.name

@description('Full ARM resource ID of the deployed storage account.')
output resStorageID string = resStorage.outputs.resourceId

@description('Blob container URL for function app deployment storage (first container when containerNames is set).')
output blobContainerURL string = !empty(containerNames)
  ? '${resStorage.outputs.primaryBlobEndpoint}${containerNames[0]}'
  : resStorage.outputs.primaryBlobEndpoint
