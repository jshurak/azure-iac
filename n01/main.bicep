targetScope = 'subscription'
param namePrefix string
param location string 
param CIDR string 
param ipAddressSpace string
param networkName string
param subnets object

@description('Resource group that hosts core landing-zone networking, secrets, and storage.')
resource coreResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${namePrefix}-core-${location}-rg'
  location: location
}

module spokeNetwork '../modules/networkspoke.bicep' = {
  scope: coreResourceGroup
  params: {
    location: location
    CIDR: CIDR
    ipAddressSpace: ipAddressSpace
    namePrefix: namePrefix
    networkName: networkName
    subnets: subnets
  }
}
