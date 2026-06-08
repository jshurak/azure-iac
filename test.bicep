

resource network 'Microsoft.Network/virtualNetworks@2025-07-01' existing = {
  name: 'js-centralus-hub-vnet'
}


module subnets 'br/public:avm/res/network/virtual-network/subnet:0.2.0' = {
  params: {
    name: 'PrivateEndpointSubnet'
    virtualNetworkName: network.name
    addressPrefix: '10.1.1.0/24'
    delegation: 'Microsoft.App/environments'
  }
}
