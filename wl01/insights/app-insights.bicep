param namePrefix string

var localResourceGroup = az.resourceGroup()
@description('Application Insights and Log Analytics workspace for the function app.')
module appInsight '../../modules/appinsight.bicep' = {
  scope: localResourceGroup
  params: {
    namePrefix: namePrefix
    appInsightsName: '${namePrefix}-appinsights'
  }
}

output appInsightResourceID string = appInsight.outputs.appInsightResourceID
output appInsightName string = appInsight.outputs.appInsightName
output appInsightInstrumentationKey string = appInsight.outputs.appInsightInstrumentationKey
output appInsightConnectionString string = appInsight.outputs.appInsightConnectionString
