using './main.bicep'

// Prefix applied to workload resource names (for example, wl01-centralus-rg).
param namePrefix = 'wl01'

// Name of the hub virtual network to peer with.
param hubNetworkName = 'js-centralus-hub-vnet'

// Resource group that hosts the hub virtual network.
param hubResourceGroupName = 'js-centralus-core-rg'

// Resource group that hosts the private DNS zone used for VNet registration.
param dnsResourceGroupName = 'js-eastus2-core-rg'
