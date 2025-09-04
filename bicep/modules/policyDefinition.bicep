@description('Deploy a policy definition and assignment at subscription scope')
param policyName string
param policyJson object
param assignmentName string
param assignmentDisplayName string
param enforcementMode string = 'DoNotEnforce'

resource policyDef 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: policyName
  properties: policyJson.properties
}

resource policyAssign 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: assignmentName
  properties: {
    displayName: assignmentDisplayName
    policyDefinitionId: policyDef.id
    enforcementMode: enforcementMode
  }
}

output policyDefId string = policyDef.id
output assignmentId string = policyAssign.id
