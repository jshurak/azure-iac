param subnetResourceID string
param privateEndpointName string = ''
param namePrefix string = 'pe'



var vprivateEndpointName = !empty(privateEndpointName) ? privateEndpointName : '${namePrefix}-${uniqueString(resourceGroup().id)}'

module privateEndpoint 'br/public:avm/res/network/private-endpoint:0.12.1' = {
  params: {
    name: vprivateEndpointName
    subnetResourceId: subnetResourceID
  }
}
