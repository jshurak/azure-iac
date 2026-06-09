@description('Principal object ID of the user-assigned managed identity for storage RBAC.')
param identityPrincipalId string

@description('Prefix used in resource names (for example, wl01).')
param namePrefix string

@description('Azure Storage replication SKU (Standard_LRS or Standard_ZRS).')
param storagesku string

@description('Storage subresources to expose via private endpoints (blob, queue, table, file, or dfs).')
param storageEndpoints array = [
  'blob'
  'queue'
  'table'
]

@description('ARM resource IDs of existing storage private DNS zones.')
param storagePrivateDnsZoneResourceIds array

@description('ARM resource ID of the subnet that hosts storage private endpoints.')
param peSubnetResourceId string

var localResourceGroup = az.resourceGroup()
//build storage account and grant rbac permission to the identity


module storage 'br/JSRegistry:storage/storage-account:v1.5.1' = {
  scope: localResourceGroup
  params: {
    storageAccountName: '${namePrefix}st${uniqueString(localResourceGroup.id)}'
    storageSku: storagesku
    containerNames: ['${namePrefix}-app-container']
    blobPublicAccess: false
    roleAssignments: [
      {
        principalId: identityPrincipalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }
      {
        principalId: identityPrincipalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Blob Data Owner'
      }
      {
        principalId: identityPrincipalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Table Data Contributor'
      }
      {
        principalId: identityPrincipalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Queue Data Contributor'
      }
    ]
  }
}



/*
@description('Storage account, blob container, and RBAC for the function app deployment and triggers.')
module storage '../../modules/storage.bicep' = {
  scope: localResourceGroup
  params: {
    storageAccountName: '${namePrefix}st${uniqueString(localResourceGroup.id)}'
    storageSku: storagesku
    containerNames: ['${namePrefix}-app-container']
    blobPublicAccess: false
    roleAssignments: [
      {
        principalId: identityPrincipalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }
      {
        principalId: identityPrincipalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Blob Data Owner'
      }
      {
        principalId: identityPrincipalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Table Data Contributor'
      }
      {
        principalId: identityPrincipalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Queue Data Contributor'
      }
    ]
  }
}
*/

//Loops through the storageEndpoints array and creates a private endpoint for each endpoint
@description('Private endpoints connecting the spoke VNet to storage subresources.')
module storagePrivateEndpoints '../../modules/privateendpoints.bicep' = [
  for (endpoint, i) in storageEndpoints: {
    scope: localResourceGroup
    params: {
      privateEndpointName: '${endpoint}-pe'
      privateDnsZoneResourceId: storagePrivateDnsZoneResourceIds[i]
      serviceID: storage.outputs.resStorageID
      subnetResourceID: peSubnetResourceId
      groupIds: [endpoint]
    }
  }
]

@description('Full ARM resource ID of the deployed storage account.')
output resStorageID string = storage.outputs.resStorageID

@description('Name of the deployed storage account.')
output resStorageName string = storage.outputs.resStorageName

@description('Blob container URL for function app deployment storage.')
output blobContainerURL string = storage.outputs.blobContainerURL
