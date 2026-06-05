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

@description('Blob container names to create in the storage account.')
param containerNames string[] = []

@description('RBAC role assignments applied to the storage account (principalId, principalType, roleDefinitionIdOrName).')
param roleAssignments array = []

var vStorageAccountName = !empty(storageAccountName)
  ? storageAccountName
  : '${namePrefix}${uniqueString(resourceGroup().id)}'

@description('StorageV2 account with public blob access disabled.')
module resStorage 'br/public:avm/res/storage/storage-account:0.32.1' = {
  params: {
    name: vStorageAccountName
    allowBlobPublicAccess: blobPublicAccess
    kind: storageKind
    skuName: storageSku
    location: resourceGroup().location
    roleAssignments: roleAssignments
    allowSharedKeyAccess: false
    blobServices: {
      containers: [
        {
          name: containerNames[0]
        }
      ]
    }
  }
}

@description('Name of the deployed storage account.')
output resStorageName string = resStorage.outputs.name

@description('Full ARM resource ID of the deployed storage account.')
output resStorageID string = resStorage.outputs.resourceId

/*
module resBlob 'br/public:avm/res/storage/storage-account/blob-service:0.1.0' = if (!empty(containerNames)) {
  params: {
    storageAccountName: resStorage.outputs.name
    containers: [
      for name in containerNames: {
        name: name
      }
    ]
  }
}
*/
@description('Blob container URL for function app deployment storage (first container when containerNames is set).')
output blobContainerURL string = !empty(containerNames)
  ? '${resStorage.outputs.primaryBlobEndpoint}${containerNames[0]}'
  : resStorage.outputs.primaryBlobEndpoint
