metadata description = 'Core storage account for shared blob data and artifacts.'

@description('Prefix used in the storage account name (for example, jscorestorage).')
param namePrefix string ='sa'

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



@description('calculate a unique name for the storage account if the storageAccountName is empty')
var vStorageAccountName = !empty(storageAccountName) ? storageAccountName : '${namePrefix}${uniqueString(resourceGroup().id)}'

@description('StorageV2 account with public blob access disabled.')
module resStorage 'br/public:avm/res/storage/storage-account:0.32.1' = {
  params: {
    name:vStorageAccountName
    allowBlobPublicAccess: blobPublicAccess
    kind: storageKind
    skuName: storageSku
    location: resourceGroup().location
  }
}

output resStorageName string = resStorage.outputs.name
output resStorageID string = resStorage.outputs.resourceId

module resBlob 'br/public:avm/res/storage/storage-account/blob-service:0.1.0' = if (!empty(containerNames)) {
  params: {
    storageAccountName: resStorage.outputs.name
    containers: [for name in containerNames: {
      name: name
    }]
  }
}


