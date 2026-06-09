targetScope = 'resourceGroup'

@description('Azure region for the VM resources.')
param location string = resourceGroup().location

@description('Prefix applied to VM and related resource names.')
param namePrefix string

@description('Resource ID of the subnet where the VM NIC will be placed.')
param subnetId string

@description('Source IP address or CIDR allowed for inbound SSH (for example, 203.0.113.10/32).')
param allowedSshSourceIp string

@description('Administrator username for the Linux VM.')
param adminUsername string = 'azureuser'

@description('SSH public key for VM authentication.')
param sshPublicKey string

@description('VM size SKU.')
param vmSize string = 'Standard_B2s'

var vmName = '${namePrefix}-linux-vm'


@description('NSG restricting inbound SSH to a single trusted source IP.')
module vmNsg 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'linux-vm-nsg-deployment'
  params: {
    name: '${vmName}-nsg'
    location: location
    securityRules: [
      {
        name: 'Allow-SSH-From-Trusted-IP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: allowedSshSourceIp
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

@description('Ubuntu Linux VM with a public IP and SSH restricted by NSG.')
module vm 'br/public:avm/res/compute/virtual-machine:0.22.1' = {
  name: 'linux-vm-deployment'
  params: {
    name: vmName
    location: location
    availabilityZone: -1
    vmSize: vmSize
    osType: 'Linux'
    adminUsername: adminUsername
    disablePasswordAuthentication: true
    imageReference: {
      publisher: 'Canonical'
      offer: 'ubuntu-26_04-lts'
      sku: 'server'
      version: '26.04.202604210'
    }
    publicKeys: [
      {
        keyData: sshPublicKey
        path: '/home/${adminUsername}/.ssh/authorized_keys'
      }
    ]
    osDisk: {
      diskSizeGB: 30
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
    }
    nicConfigurations: [
      {
        nicSuffix: '-nic-01'
        enableAcceleratedNetworking: false
        networkSecurityGroupResourceId: vmNsg.outputs.resourceId
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: subnetId
            pipConfiguration: {
              publicIpNameSuffix: '-pip'
            }
          }
        ]
      }
    ]
  }
}

output vmName string = vm.outputs.name
output vmResourceId string = vm.outputs.resourceId
output nsgName string = vmNsg.outputs.name
