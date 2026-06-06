using './main.bicep'

param hubResourceGroup = 'js-core-rg'
param hubNetworkName = 'js-hub-vnet'
param spokeNetworks =  {
  'js-westus-vnet': 'js-core-westus-rg'
  'js-centralus-vnet': 'js-core-centralus-rg'
}
