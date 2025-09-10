@description('Module to onboard a Log Analytics workspace to Microsoft Sentinel (SecurityInsights)')
param workspaceName string
@description('The sentinel onboarding resource name, usually "default"')
param sentinelName string = 'default'
@description('Set to true to indicate the workspace uses customer managed keys')
param customerManagedKey bool = false

// Use the Sentinel onboardingStates resource under the workspace provider namespace
// Declare the workspace parent resource (existing) so we can create the child provider resource
resource workspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: workspaceName
}

// The onboardingStates resource is provided by the Microsoft.SecurityInsights provider
resource sentinelOnboard 'Microsoft.SecurityInsights/onboardingStates@2025-06-01' = {
  name: sentinelName
  scope: workspace
  properties: {
    customerManagedKey: customerManagedKey
  }
}

output sentinelResourceId string = sentinelOnboard.id
