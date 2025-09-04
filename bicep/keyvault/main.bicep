@description('Prefix used for naming the Key Vault')
param namePrefix string
@description('Environment short name')
param environment string = 'dev'
@description('Location')
param location string = resourceGroup().location
@description('SKU (standard or premium)')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'
@description('Tags')
param tags object = {}
@description('Enable RBAC authorization (true = ignore accessPolicies)')
param enableRbacAuthorization bool = true
@description('Access policies (ignored if enableRbacAuthorization = true)')
param accessPolicies array = []

module kv '../modules/keyVault.bicep' = {
  name: 'keyVaultModule'
  params: {
    namePrefix: namePrefix
    environment: environment
    location: location
    skuName: skuName
    tags: tags
    enableRbacAuthorization: enableRbacAuthorization
    accessPolicies: accessPolicies
  }
}

output keyVaultName string = kv.outputs.keyVaultName
output keyVaultUri string = kv.outputs.keyVaultUri
output keyVaultId string = kv.outputs.keyVaultId
