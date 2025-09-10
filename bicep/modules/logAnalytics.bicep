@description('Module to create a Log Analytics workspace')
param workspaceName string
param location string
param sku string = 'PerGB2018'
param retentionInDays int = 30
param tags object = {}

resource law 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
  }
}

output workspaceId string = law.id
output workspaceCustomerId string = law.properties.customerId
