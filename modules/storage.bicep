metadata description = 'Core storage account for shared blob data and artifacts.'

@description('Prefix used in the storage account name (for example, jscorestorage).')
param namePrefix string

@description('Azure Storage replication SKU (Standard_LRS or Standard_ZRS).')
param storageSku string

@description('The storage account type')
param storageKind string = 'StorageV2'

@description('Public access policy for blob.')
param blobPublicAccess bool = false

@description('Blob container names to create in the storage account.')
param containerNames string[] = []

@description('StorageV2 account with public blob access disabled.')
module resStorage 'br/public:avm/res/storage/storage-account:0.32.1' = {
  params: {
    name: '${namePrefix}${uniqueString(resourceGroup().id)}'
    allowBlobPublicAccess: blobPublicAccess
    kind: storageKind
    skuName: storageSku
    location: resourceGroup().location
  }
}

output resStorageName string = resStorage.outputs.name

module resBlob 'br/public:avm/res/storage/storage-account/blob-service:0.1.0' = if (!empty(containerNames)) {
  params: {
    storageAccountName: resStorage.outputs.name
    containers: [for name in containerNames: {
      name: name
    }]
  }
}
