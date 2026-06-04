metadata description = 'Linux App Service plan for Flex Consumption function apps (SKU FC1).'

@description('Explicit App Service plan name. When empty, a name is generated from namePrefix and the resource group id.')
param appServicePlanName string

@description('Prefix used when generating the plan name (for example, asp).')
param namePrefix string = 'asp'

@description('App Service plan SKU. FC1 is required for Flex Consumption function apps.')
param skuName string = 'FC1'

var vAppServerPlanName = !empty(appServicePlanName) ? appServicePlanName : '${namePrefix}-${uniqueString(resourceGroup().id)}'

@description('Reserved Linux App Service plan from Azure Verified Modules.')
module appServicePlan 'br/public:avm/res/web/serverfarm:0.7.0' = {
  params: {
    name: vAppServerPlanName
    reserved: true
    skuName: skuName
  }
}

@description('Full ARM resource ID of the deployed App Service plan.')
output appServicePlanResourceID string = appServicePlan.outputs.resourceId
