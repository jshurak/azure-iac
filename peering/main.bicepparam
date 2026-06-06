using './main.bicep'

param hubNetworkName = 'js-hub-vnet'
param hubResourceGroup = 'js-core-rg'

param spokeNetworkNames object = {
  'js-westus-vnet': 'js-core-westus-rg'
  'js-centralus-vnet': 'js-core-centralus-rg'
}
