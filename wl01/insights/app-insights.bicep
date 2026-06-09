@description('Prefix used when generating Log Analytics and Application Insights names (for example, wl01).')
param namePrefix string

var localResourceGroup = az.resourceGroup()
@description('Application Insights and Log Analytics workspace for the function app.')
module appInsight 'br/JSRegistry:ops/app-insight:v1.0.0' = {
  scope: localResourceGroup
  params: {
    namePrefix: namePrefix
    appInsightsName: '${namePrefix}-appinsights'
  }
}

@description('Full ARM resource ID of the deployed App Insights.')
output appInsightResourceID string = appInsight.outputs.appInsightResourceID

@description('Name of the deployed App Insights.')
output appInsightName string = appInsight.outputs.appInsightName

@description('Instrumentation key of the deployed App Insights.')
output appInsightInstrumentationKey string = appInsight.outputs.appInsightInstrumentationKey

@description('Connection string of the deployed App Insights.')
output appInsightConnectionString string = appInsight.outputs.appInsightConnectionString
