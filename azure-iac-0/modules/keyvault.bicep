metadata description = 'Key Vault for landing-zone secrets and certificates.'

@description('Prefix used in the Key Vault name (for example, js-kevyault).')
param namePrefix string

@description('Azure region for the Key Vault.')
param location string = resourceGroup().location

@description('Key Vault with RBAC authorization and template-deployment access enabled.')
module keyVault 'br/public:avm/res/key-vault/vault:0.13.3' = {
  params: {
    name: '${namePrefix}-kevyault'
    enableRbacAuthorization: true
    enableVaultForTemplateDeployment: true
    location: location
  }
}
