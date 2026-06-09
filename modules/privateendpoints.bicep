metadata description = 'Private endpoint for Azure Blob storage on an existing subnet.'

@description('Full ARM resource ID of the subnet that hosts the private endpoint.')
param subnetResourceID string

@description('Explicit private endpoint name. When empty, a name is generated from namePrefix and the resource group id.')
param privateEndpointName string = ''

@description('Prefix used when generating the private endpoint name (for example, pe).')
param namePrefix string = 'pe'

@description('Full ARM resource ID of the target service (for example, a storage account).')
param serviceID string

@description('Group IDs for the private endpoint. This is the subresource, ie storage would be blob.file,queue, table etc.')
param groupIds string[] = []

@description('Full ARM resource ID of the private DNS zone for private endpoint name resolution.')
param privateDnsZoneResourceId string

var vprivateEndpointName = !empty(privateEndpointName)
  ? privateEndpointName
  : '${namePrefix}-${uniqueString(resourceGroup().id)}'

@description('Private endpoint with a blob private link connection from Azure Verified Modules.')
module privateEndpoint 'br/public:avm/res/network/private-endpoint:0.12.1' = {
  params: {
    name: vprivateEndpointName
    subnetResourceId: subnetResourceID
    privateLinkServiceConnections: [
      {
        name: vprivateEndpointName
        properties: {
          privateLinkServiceId: serviceID
          groupIds: groupIds
        }
      }
    ]
    customNetworkInterfaceName: '${vprivateEndpointName}-nic'
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        {
          name: '${vprivateEndpointName}-dns-config'
          privateDnsZoneResourceId: privateDnsZoneResourceId
        }
      ]
    }
  }
}
