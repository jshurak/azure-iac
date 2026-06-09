//param resourceGroupName string
@description('Prefix used in resource names (for example, wl01).')
param namePrefix string

var localResrourceGroup = az.resourceGroup()


//start identity buildout
@description('User-assigned managed identity for function app storage access.')
module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.5.1' = {
  scope: localResrourceGroup
  params: {
    name: '${namePrefix}-identity'
  }
}

@description('Principal object ID of the user-assigned managed identity.')
output principalId string = identity.outputs.principalId

@description('Full ARM resource ID of the user-assigned managed identity.')
output resourceId string = identity.outputs.resourceId

@description('Client ID of the user-assigned managed identity.')
output clientId string = identity.outputs.clientId
//end identity buildout
