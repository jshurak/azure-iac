using './main.bicep'

param namePrefix = 'js'
param location = 'centralus'


param ipAddressSpace = '10.1.0.0'
param CIDR = '/16'

param storageSku = 'Standard_LRS'



param networkName = '${namePrefix}-${location}-hub-vnet'


param hubNetworkName = 'js-eastus2-hub-vnet'

param hubResourceGroupName = 'js-eastus2-core-rg'

param companyDomain = 'js-company.com'
