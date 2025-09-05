param location string = resourceGroup().location
param workspaceName string = 'hub-law'
param workspaceSku string = 'PerGB2018'
param retentionInDays int = 30
param tags object = {}
param sentinelName string = 'default'
param customerManagedKey bool = false

module law '../modules/logAnalytics.bicep' = {
  name: 'hubLogAnalytics'
  params: {
    workspaceName: workspaceName
    location: location
    sku: workspaceSku
    retentionInDays: retentionInDays
    tags: tags
  }
}

module enableSentinel '../modules/sentinel.bicep' = {
  name: 'enableSentinel'
  params: {
    workspaceName: workspaceName
    sentinelName: sentinelName
    customerManagedKey: customerManagedKey
  }
  dependsOn: [law]
}

output workspaceId string = law.outputs.workspaceId
output sentinelId string = enableSentinel.outputs.sentinelResourceId
