param identityPrincipalId string
param namePrefix string
param storagesku string
param storageEndpoints array = [
  'blob'
  'queue'
  'table'
]

param storagePrivateDnsZoneResourceIds array
param peSubnetResourceId string

var localResourceGroup = az.resourceGroup()
//build storage account and grant rbac permission to the identity
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

output resStorageID string = storage.outputs.resStorageID
output resStorageName string = storage.outputs.resStorageName
output blobContainerURL string = storage.outputs.blobContainerURL
