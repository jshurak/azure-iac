using './main.bicep'

param namePrefix = 'js'
param location = 'eastus2'

param ipAddressSpace = '10.0.0.0'
param CIDR = '/16'

param storageSku = 'Standard_LRS'


param ownerName = 'Jeff Shurak'
