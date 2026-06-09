targetScope = 'resourceGroup'

@description('Prefix used in resource names (for example, js).')
param namePrefix string

@description('Subnet ID for the workload subnet.')
param workLoadSubnetID string

@description('Name of the nic for the test vm.')
param nicName string = '${namePrefix}-test-vm-nic'

@description('SSH key for the test vm.')
param sshKey string

var vNicName = !empty(nicName) ? nicName : '${namePrefix}-test-vm-nic'

module vm 'br/public:avm/res/compute/virtual-machine:0.22.1' = {
  params: {
    name: '${namePrefix}-test-vm'
    availabilityZone: 1
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: vNicName
            subnetResourceId: workLoadSubnetID
            pipConfiguration: {
              publicIpNameSuffix: '-pip'
            }       
          }
        ]
      }
    ]
    osDisk: {
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    osType: 'Linux'
    vmSize: 'Standard_DS1_v2'
    adminUsername: 'adminuser'
    disablePasswordAuthentication: true
    imageReference: {
      publisher: 'Canonical'
      offer: 'ubuntu-26_04-lts'
      sku: 'server'
      version: '26.04.202604210'
    }
    publicKeys: [
      {
        path: '/home/adminuser/.ssh/authorized_keys'
        keyData: sshKey
      }
    ]
  }
}
