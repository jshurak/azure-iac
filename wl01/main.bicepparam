using './main.bicep'



param hubNetworkName = 'js-centralus-hub-vnet'
param hubResourceGroupName = 'js-centralus-core-rg'
param networkName = '${namePrefix}-vnet'
param dnsResourceGroupName = 'js-eastus2-core-rg'
param functionAppName = 'wl02-function-app'
param namePrefix = 'wl02'
