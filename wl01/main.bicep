metadata description = 'This workload deploys a function app with spoke networking, private endpoints, and identity-based storage access.'
targetScope = 'subscription'

/*
For this workload, we will create the following
a resource group
a spoke network with peering between it's region's hub network
a user mmanaged identity and assign rolesto handle communication between the function app, storage account and app inights
it will leverage a private endpoint to communicate privately, with existing private dns zone
it will create the app insight and log analytics workspace
an app service plan
the python function app
*/

@description('Name of the hub virtual network to peer with.')
param hubNetworkName string

@description('Resource group that hosts the hub virtual network.')
param hubResourceGroupName string

@description('Name of the spoke virtual network for this workload.')
param networkName string = '${namePrefix}-vnet'

@description('Resource group that hosts the private DNS zone used for VNet registration.')
param dnsResourceGroupName string

@description('Prefix applied to workload resource names (for example, wl01-centralus-rg).')
param namePrefix string = 'wl01'

@description('Azure region for the workload resource group and deployed resources.')
param location string = 'centralus'

@description('Owner name applied as a tag on deployed resources.')
param ownerName string = 'Jeff Shurak'

@description('Replication SKU for the workload storage account (LRS or zone-redundant ZRS).')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
])
param storagesku string = 'Standard_LRS'

//Function apps require blob/queue/table contributor roles.  In order to keep this solution off the 
//public internet, well will create dns zones and private endpoints for blob, queue, and table services.
@description('Storage subresources to expose via private endpoints (blob, queue, table, file, or dfs).')
@allowed([
  'blob'
  'queue'
  'table'
])
param storageEndpoints array = [
  'blob'
  'queue'
  'table'
]

@description('Name of the Flex Consumption function app.')
param functionAppName string = '${namePrefix}-function-app'

//any existing resources that we need for this.  
//In this case, we need a private dns zone to set registration for the workload vNet.
@description('Private dns zone for our production environment.')
resource privateDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(dnsResourceGroupName)
  name: 'js-company.com'
}

@description('Resource group that hosts the workload.')
resource wlResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${namePrefix}-${location}-rg'
  location: location
}

//start network buildout
@description('Virtual network and subnets for the workload.')
module wlNetwork '../modules/virtualnetwork.bicep' = {
  scope: wlResourceGroup
  params: {
    networkName: networkName
    location: location
    CIDR: '/20'
    ipAddressSpace: '10.2.0.0'
    namePrefix: namePrefix
    networkType: 'spoke'
  }
}

@description('Subnet reserved for private endpoints.')
module peSubnet 'br/public:avm/res/network/virtual-network/subnet:0.2.0' = {
  scope: wlResourceGroup
  params: {
    name: 'PrivateEndpointSubnet'
    virtualNetworkName: wlNetwork.outputs.NetworkName
    addressPrefix: '10.2.1.0/24'
  }
}

@description('Subnet delegated to Azure Functions Flex Consumption.')
module fnSubnet 'br/public:avm/res/network/virtual-network/subnet:0.2.0' = {
  scope: wlResourceGroup
  params: {
    name: 'FunctionAppSubnet'
    virtualNetworkName: wlNetwork.outputs.NetworkName
    addressPrefix: '10.2.2.0/24'
    delegation: 'Microsoft.App/environments'
  }
  dependsOn: [
    peSubnet
  ]
}



@description('Links the spoke VNet to the existing private DNS zone for auto-registration.')
module hubNetworkLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = {
  scope: resourceGroup(dnsResourceGroupName)
  params: {
    name: '${networkName}-dns-link'
    privateDnsZoneName: privateDNSZone.name
    virtualNetworkResourceId: wlNetwork.outputs.NetworkResourceID
    location: 'global'
    registrationEnabled: true
    tags: {
      Environment: 'Prod'
      Owner: ownerName
    }
  }
}


@description('Bidirectional peering between the hub and spoke virtual networks.')
module peering '../modules/networkpeering.bicep' = {
  scope: subscription()
  params: {
    net1ResourceGroup: hubResourceGroupName
    net1NetworkName: hubNetworkName
    net2ResourceGroup: wlResourceGroup.name
    net2NetworkName: networkName
    allowGatewayTransit: false
  }
  dependsOn: [
    wlNetwork
  ]
}
//end network buildout

//start identity buildout
@description('User-assigned managed identity for function app storage access.')
module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.5.1' = {
  scope: wlResourceGroup
  params: {
    name: '${namePrefix}-identity'
  }
}
//end identity buildout

//build storage account and grant rbac permission to the identity
@description('Storage account, blob container, and RBAC for the function app deployment and triggers.')
module storage '../modules/storage.bicep' = {
  scope: wlResourceGroup
  params: {
    storageAccountName: '${namePrefix}st${uniqueString(wlResourceGroup.id)}'
    storageSku: storagesku
    containerNames: ['${namePrefix}-app-container']
    blobPublicAccess: false
    roleAssignments: [
      {
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }
      {
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Blob Data Owner'
      }
      {
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Table Data Contributor'
      }
      {
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Queue Data Contributor'
      }
    ]
  }
}


//moved to core infrastructure hub
/*//Loops through the storageEndpoints array and creates a private dns zone for each endpoint
@description('Private DNS zones for storage private link endpoints.')
module storagePrivateDNSZone 'br/public:avm/res/network/private-dns-zone:0.8.1' = [
  for endpoint in storageEndpoints: {
    scope: wlResourceGroup
    params: {
      name: 'privatelink.${endpoint}.core.windows.net'
      location: 'global'
      virtualNetworkLinks: [
        {
          virtualNetworkResourceId: wlNetwork.outputs.NetworkResourceID
        }
      ]
    }
  }
]*/

//Loops through the storageEndpoints array and creates a private endpoint for each endpoint
@description('Private endpoints connecting the spoke VNet to storage subresources.')
module storagePrivateEndpoints '../modules/privateendpoints.bicep' = [
  for (endpoint, i) in storageEndpoints: {
    scope: wlResourceGroup
    params: {
      privateEndpointName: '${endpoint}-pe'
      privateDnsZoneResourceId: storagePrivateDNSZone[i].outputs.resourceId
      serviceID: storage.outputs.resStorageID
      subnetResourceID: peSubnet.outputs.resourceId
      groupIds: [endpoint]
    }
  }
]

//end storage account buildout

//build app insight and log analytics workspace
@description('Application Insights and Log Analytics workspace for the function app.')
module appInsight '../modules/appinsight.bicep' = {
  scope: wlResourceGroup
  params: {
    namePrefix: namePrefix
    appInsightsName: '${namePrefix}-appinsights'
  }
}
//end app insight and log analytics workspace buildout

//build the app service, Function App, private dns zone and endpoint.  We will also register the private dns zone with the hub vNet.

@description('Private DNS zones for Function App private link endpoints.')
resource functionAppPrivateDNSZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(dnsResourceGroupName)
  name: 'privatelink.AzureWebSites.net'
}

@description('Links the spoke VNet to the existing private DNS zone for auto-registration.')
module dnsNetworkLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = {
  scope: resourceGroup(dnsResourceGroupName)
  params: {
    name: '${networkName}-dns-link'
    privateDnsZoneName: functionAppPrivateDNSZone.name
    virtualNetworkResourceId: wlNetwork.outputs.NetworkResourceID
    location: 'global'
    registrationEnabled: false
    tags: {
      Environment: 'Prod'
      Owner: ownerName
    }
  }
}






@description('Flex Consumption App Service plan for the function app.')
module appPlan '../modules/appserviceplan.bicep' = {
  scope: wlResourceGroup
  params: {
    appServicePlanName: '${namePrefix}-appservice-plan'
  }
}

@description('Python Flex Consumption function app with identity-based deployment storage.')
module functionApp '../modules/functionapp.bicep' = {
  scope: wlResourceGroup
  params: {
    functionAppName: functionAppName
    virtualNetworkSubnetResourceId: fnSubnet.outputs.resourceId
    storageAccountResourceID: storage.outputs.resStorageID
    storageAccountName: storage.outputs.resStorageName
    userAssignedIdentityClientID: identity.outputs.clientId
    blobContainerURL: storage.outputs.blobContainerURL
    serverFarmResourceID: appPlan.outputs.appServicePlanResourceID
    userAssignedResourceID: identity.outputs.resourceId
    appInsightInstrumentationKey: appInsight.outputs.appInsightInstrumentationKey
  }
  dependsOn: [
    storagePrivateEndpoints
  ]
}

@description('Private endpoint for inbound access to the function app.')
module appPrivateEndpoint '../modules/privateendpoints.bicep' = {
  scope: wlResourceGroup
  params: {
    privateDnsZoneResourceId: functionAppPrivateDNSZone.id
    privateEndpointName: '${namePrefix}-${functionApp.name}-pe'
    serviceID: functionApp.outputs.resourceId
    subnetResourceID: peSubnet.outputs.resourceId
    groupIds: ['sites']
  }
}
//end function app buildout
