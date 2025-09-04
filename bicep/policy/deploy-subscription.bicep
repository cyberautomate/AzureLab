targetScope = 'subscription'

// Subscription-scoped deployment to create policy definitions and assignments
// Default enforcementMode set to 'Default' to enforce the policy
param enforcementMode string = 'Default'

var policyDefinition = json(loadTextContent('deny-public-ip.json'))

resource policyDef 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'Deny-Public-IP-Addresses-AzureLab'
  properties: policyDefinition.properties
}

resource policyAssign 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'DenyPublicIPsAssignment-DoNotEnforce'
  properties: {
    displayName: 'Deny public IPs (DoNotEnforce)'
    policyDefinitionId: policyDef.id
    enforcementMode: enforcementMode
  }
}

output assignmentId string = policyAssign.id
