@description('Main deployment that composes modules')
param namePrefix string
param environment string = 'dev'
param location string = resourceGroup().location
param tags object = {}


module storage 'modules/storageAccount.bicep' = {
  name: 'storageModule'
  params: {
    namePrefix: namePrefix
    environment: environment
    location: location
    tags: tags
  }
}

output storageAccountId string = storage.outputs.storageAccountId
output storageAccountName string = storage.outputs.storageAccountName
output storagePrimaryEndpoints object = storage.outputs.primaryEndpoints

