using './main.bicep'

param namePrefix = 'js'
param location = 'centralus'
param dnsResourceGroup = 'js-eastus2-core-rg'

param ipAddressSpace = '10.1.0.0'
param CIDR = '/16'

param storageSku = 'Standard_LRS'


param ownerName = 'Jeff Shurak'


param networkName = '${namePrefix}-${location}-hub-vnet'
