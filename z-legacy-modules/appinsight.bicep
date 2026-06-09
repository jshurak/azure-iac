@description('Explicit Log Analytics workspace name. When empty, a name is generated from namePrefix.')
param logAnalyticsName string = ''

@description('Explicit Application Insights resource name. When empty, a name is generated from namePrefix.')
param appInsightsName string = ''

@description('Prefix used when generating Log Analytics and Application Insights names (for example, wl01).')
param namePrefix string 

var vLogAnalyticsName = !empty(logAnalyticsName) ? logAnalyticsName : '${namePrefix}-loganalytics'
var vAppInsightsName = !empty(appInsightsName) ? appInsightsName : '${namePrefix}-appinsights'


@description('Log Analytics workspace for function app diagnostics and telemetry retention.')
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.15.1' = {
  params: {
    name: vLogAnalyticsName
    dailyQuotaGb: '2'
    dataRetention: 30
  }
}


@description('Application Insights component linked to the Log Analytics workspace.')
module appInsights 'br/public:avm/res/insights/component:0.7.2' = {
  params: {
    name: vAppInsightsName
    workspaceResourceId: logAnalytics.outputs.resourceId
    applicationType: 'web'   
  }
}


@description('Full ARM resource ID of the deployed App Insights.')
output appInsightResourceID string = appInsights.outputs.resourceId

@description('Name of the deployed App Insights.')
output appInsightName string = appInsights.outputs.name

@description('Instrumentation key of the deployed App Insights.')
output appInsightInstrumentationKey string = appInsights.outputs.instrumentationKey

@description('Connection string of the deployed App Insights.')
output appInsightConnectionString string = appInsights.outputs.connectionString
