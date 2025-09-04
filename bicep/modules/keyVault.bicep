@description('Prefix for naming resources')
param namePrefix string
@description('Environment short name (e.g., dev, test, prod)')
param environment string = 'dev'
@description('Location for the Key Vault')
param location string = resourceGroup().location
@description('Key Vault SKU name (standard or premium)')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'
@description('Tags to apply to the Key Vault')
param tags object = {}
@description('Array of access policy objects (tenantId, objectId, permissions)')
param accessPolicies array = []
@description('Enable purge protection (cannot be disabled once enabled)')
param enablePurgeProtection bool = true
@description('Enable soft delete (always on for newer API versions, kept for clarity)')
param enableSoftDelete bool = true
@description('Public network access (Enabled or Disabled)')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'
@description('Optional RBAC authorization usage flag (if true, accessPolicies should normally be empty)')
param enableRbacAuthorization bool = true

var vaultName = toLower(replace('${namePrefix}-${environment}-kv','--','-'))

// NOTE: Simpler handling: caller provides properly shaped accessPolicies array matching schema
// When RBAC authorization is enabled, we ignore any provided access policies
var computedAccessPolicies = enableRbacAuthorization ? [] : accessPolicies

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enablePurgeProtection: enablePurgeProtection
    enableSoftDelete: enableSoftDelete
    publicNetworkAccess: publicNetworkAccess
    enableRbacAuthorization: enableRbacAuthorization
    accessPolicies: computedAccessPolicies
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
