param appServicePlanName string
param namePrefix string = 'asp'
param skuName string = 'FC1'

var vAppServerPlanName = !empty(appServicePlanName) ? appServicePlanName : '${namePrefix}-${uniqueString(resourceGroup().id)}'

module appServicePlan 'br/public:avm/res/web/serverfarm:0.7.0' = {
  params: {
    name: vAppServerPlanName
    reserved: true
    skuName: skuName
  }
}

output appServicePlanResourceID string = appServicePlan.outputs.resourceId
