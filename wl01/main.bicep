targetScope = 'subscription'

param namePrefix string 
param storagesku string 
param location string 
param subnetName string
param vnetName string
param vnetResourceGroup string


//create our resource group
@description('Resource group that hosts workload.')
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${namePrefix}-rg'
  location: location
}

//create an identity for function app to access the storage account
module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.5.1' = {
  scope: resourceGroup
  params: {
    name: '${namePrefix}-identity'
  }
}


//function app requires we have some storage for triggers
module storage '../modules/storage.bicep' = {
  scope: resourceGroup
  params: {
    storageAccountName: '${namePrefix}stacc'
    storageSku: storagesku
    containerNames: ['${namePrefix}-app-container']
    blobPublicAccess: false
  }
}


module appPlan '../modules/appserviceplan.bicep' = {
  scope: resourceGroup
  params: {
    appServicePlanName: '${namePrefix}-appservice-plan'
  }
}


//get network resources
resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' existing = {
  scope: az.resourceGroup(vnetResourceGroup)
  name: vnetName
}
resource privateLinkSubnet 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' existing = {
  parent: vnet
  name: subnetName
}


module privateEndpoint '../modules/privateendpoints.bicep' = {
  scope: resourceGroup
  params: {
    serviceID: storage.outputs.resStorageID
    subnetResourceID: privateLinkSubnet.id
  }
}
