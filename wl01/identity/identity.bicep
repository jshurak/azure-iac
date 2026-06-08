//param resourceGroupName string
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

output principalId string = identity.outputs.principalId
output resourceId string = identity.outputs.resourceId
output clientId string = identity.outputs.clientId
//end identity buildout
