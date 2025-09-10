targetScope = 'subscription'

@description('Resource group name containing the Hub VNet')
param hubResourceGroupName string
@description('Name of the Hub VNet')
param hubVnetName string = 'hub-vnet'

@description('Resource group name containing the Spoke VNet')
param spokeResourceGroupName string
@description('Name of the Spoke VNet')
param spokeVnetName string

@description('Allow forwarded traffic on both peerings')
param allowForwardedTraffic bool = true
@description('Enable gateway transit from hub to spoke (hub allows transit, spoke uses remote gateways)')
param enableGatewayTransit bool = true

var hubVnetId = resourceId(subscription().subscriptionId, hubResourceGroupName, 'Microsoft.Network/virtualNetworks', hubVnetName)
var spokeVnetId = resourceId(subscription().subscriptionId, spokeResourceGroupName, 'Microsoft.Network/virtualNetworks', spokeVnetName)

// Spoke -> Hub peering (spoke uses remote gateways when enabled)
module spokeToHub '../modules/vnetPeering.bicep' = {
  name: '${spokeVnetName}-to-${hubVnetName}'
  scope: resourceGroup(spokeResourceGroupName)
  params: {
    peeringName: '${spokeVnetName}-to-${hubVnetName}'
    remoteVnetId: hubVnetId
    localVnetName: spokeVnetName
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: false
    useRemoteGateways: enableGatewayTransit
  }
}

// Hub -> Spoke peering (hub allows gateway transit when enabled)
module hubToSpoke '../modules/vnetPeering.bicep' = {
  name: '${hubVnetName}-to-${spokeVnetName}'
  scope: resourceGroup(hubResourceGroupName)
  params: {
    peeringName: '${hubVnetName}-to-${spokeVnetName}'
    remoteVnetId: spokeVnetId
    localVnetName: hubVnetName
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: enableGatewayTransit
    useRemoteGateways: false
  }
}

output hubToSpokePeeringId string = hubToSpoke.outputs.peeringId
output spokeToHubPeeringId string = spokeToHub.outputs.peeringId
