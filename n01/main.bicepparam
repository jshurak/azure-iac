using './main.bicep'

param namePrefix = 'js'
param location = 'westus'
param CIDR = '/16'
param ipAddressSpace = '10.1.0.0'
param networkName = '${namePrefix}-${location}-vnet'
param subnets = {
  workload: '24'
}
param privateDNSZoneName = 'js-company.com'
param globalResourceGroup = 'js-core-rg'
param ownerName = 'Jeff Shurak'
