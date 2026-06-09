targetScope = 'subscription'
metadata description = 'Subscription-scoped landing zone: core resource group, hub network, Key Vault, and storage. This is the second region deployment.'

@description('Azure region for the core resource group and deployed modules.')
param location string

@description('Prefix applied to resource names (for example, js-core-rg, js-hub-vnet).')
param namePrefix string

@description('Replication SKU for the core storage account (LRS or zone-redundant ZRS).')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
])
param storageSku string

@description('Base IPv4 address for the hub virtual network, without the CIDR suffix (for example, 10.0.0.0).')
param ipAddressSpace string

@description('CIDR suffix for the hub VNet, including the leading slash (for example, /16).')
param CIDR string

@description('Resource group that hosts the private dns zone.')
param hubResourceGroupName string

@description('Company domain for the private dns zone.')
param companyDomain string

@description('Name of the hub virtual network to peer with.')
param hubNetworkName string

@description('Name of the virtual network. to create')
param networkName string = '${namePrefix}-${location}-hub-vnet'

@description('When true, deploys a Linux VM with a public IP in the workload subnet.')
param deployLinuxVm bool = false

@description('Source IP or CIDR allowed for inbound SSH to the Linux VM (for example, 203.0.113.10/32).')
param allowedSshSourceIp string = ''

@description('SSH public key for Linux VM authentication.')
@secure()
param sshPublicKey string = ''

@description('Administrator username for the Linux VM.')
param vmAdminUsername string = 'azureuser'

@description('VM size SKU for the Linux VM.')
param vmSize string = 'Standard_B2s'


@description('Resource group that hosts core landing-zone networking, secrets, and storage.')
resource coreResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${namePrefix}-${location}-core-rg'
  location: location
}



@description('Hub virtual network with cross-region peering and private DNS zone links.')
module coreNetwork './network/network.bicep' = {
  scope: coreResourceGroup
  params: {
    companyDomain: companyDomain
    resourceGroupName: coreResourceGroup.name
    networkName: networkName
    namePrefix: namePrefix
    CIDR: CIDR
    ipAddressSpace: ipAddressSpace
    hubResourceGroupName: hubResourceGroupName
    hubNetworkName: hubNetworkName
  }
}

@description('Key Vault for secrets and certificates used by the landing zone.')
module coreKeyvault 'br/JSRegistry:key-vault:v1.0.0' = {
  scope: coreResourceGroup
  params: {
    location: location
    namePrefix: '${namePrefix}-${location}'
  }
}

@description('Core storage account for diagnostics, artifacts, or shared blob data.')
module coreStorage 'br/JSRegistry:storage/storage-account:v1.5.1' = {
  scope: coreResourceGroup
  params: {
    namePrefix: namePrefix
    storageSku: storageSku
    storageAccountName: '${namePrefix}${location}corestorage'
  }
}

@description('Optional Linux VM with public IP and SSH restricted to a trusted source IP.')
module linuxVm './compute/vm.bicep' = if (deployLinuxVm) {
  scope: coreResourceGroup
  params: {
    location: location
    namePrefix: namePrefix
    subnetId: coreNetwork.outputs.workloadSubnetId
    allowedSshSourceIp: allowedSshSourceIp
    adminUsername: vmAdminUsername
    sshPublicKey: sshPublicKey
    vmSize: vmSize
  }
}

