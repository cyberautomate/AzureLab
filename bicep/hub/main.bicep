param location string = resourceGroup().location
param tags object = {}
@description('Firewall tier: Basic | Standard | Premium')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param firewallTier string = 'Basic'

var ipPlan = json(loadTextContent('../ip-plan.json'))

module hubVnet '../modules/vnet.bicep' = {
  name: 'hubVnet'
  params: {
    vnetName: 'hub-vnet'
    vnetAddressPrefix: ipPlan.hub.vnetCidr
    location: location
    tags: tags
    subnets: [
      {
        name: 'hub-vm-subnet-1'
        prefix: ipPlan.hub.subnets.hubVmSubnet1
      }
      {
        name: 'hub-vm-subnet-2'
        prefix: ipPlan.hub.subnets.hubVmSubnet2
      }
      {
        name: 'hub-container-subnet'
        prefix: ipPlan.hub.subnets.hubContainerSubnet
        delegation: {
          name: 'containerDelegation'
          properties: {
            serviceName: 'Microsoft.ContainerInstance/containerGroups'
          }
        }
      }
      {
        name: 'AzureFirewallSubnet'
        prefix: ipPlan.hub.subnets.azureFirewallSubnet
      }
      // Management subnet required for Basic tier
      {
        name: 'AzureFirewallManagementSubnet'
        prefix: ipPlan.hub.subnets.azureFirewallManagementSubnet
      }
      {
        name: 'GatewaySubnet'
        prefix: ipPlan.hub.subnets.gatewaySubnet
      }
    ]
  }
}

module firewall '../modules/azureFirewall.bicep' = {
  name: 'azureFirewall'
  params: {
    firewallName: 'hub-firewall'
    location: location
    publicIpName: 'hub-firewall-pip'
    virtualNetworkName: 'hub-vnet'
    subnetName: 'AzureFirewallSubnet'
    managementSubnetName: 'AzureFirewallManagementSubnet'
    firewallTier: firewallTier
    tags: tags
  }
  dependsOn: [
    hubVnet
  ]
}

// Create a hub route table skeleton - spokes will reference this route table's id
module hubRouteTable '../modules/routeTable.bicep' = {
  name: 'hubRouteTable'
  params: {
    routeTableName: 'hub-udr'
    location: location
    routes: [
      {
        name: 'default-route-to-firewall'
        addressPrefix: '0.0.0.0/0'
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress: firewall.outputs.firewallPrivateIp
      }
    ]
  }
}

// Deploy (test) policy definition and assignment to prevent public IPs in spokes
// Note: subscription-scoped policy is deployed separately with
// `bicep/policy/deploy-subscription.bicep` (see docs/deploy/hub.md)

output hubVnetId string = hubVnet.outputs.vnetId
output firewallId string = firewall.outputs.firewallId
output firewallPublicIp string = firewall.outputs.firewallPublicIp
