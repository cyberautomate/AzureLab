@description('Create spoke VNet in LAB-Blue subscription and peer to hubVnet')
param location string = 'westus2'
param vnetName string = 'labblue-spoke-vnet'
param vnetAddressPrefix string = '10.10.0.0/16'
param subnets array = [
  {
    name: 'default'
    prefix: '10.10.0.0/24'
  }
]
param hubSubscriptionId string
param hubVnetName string = 'hubVnet'
param hubFirewallPrivateIp string // optional: if you need to reference firewall IP for UDR next hop
param tags object = {}

// Create VNet using shared module
module vnetModule '../bicep/modules/vnet.bicep' = {
  name: 'vnetModule'
  params: {
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    location: location
    tags: tags
    subnets: subnets
  }
}

// Route table for outbound internet via hub firewall
resource rt 'Microsoft.Network/routeTables@2022-07-01' = {
  name: '${vnetName}-rt'
  location: location
  tags: tags
  properties: {
    routes: [
      {
        name: 'default-internet'
        properties: {
          addressPrefix: '0.0.0.0/0'
          // nextHopType will be VirtualAppliance and nextHopIpAddress should point to Firewall private IP in hub
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: hubFirewallPrivateIp
        }
      }
    ]
  }
}

// Associate route table to first subnet
// Associate route table to the first subnet by redeploying the subnet resource with routeTable
resource subnetWithRt 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  name: '${vnetName}/${subnets[0].name}'
  properties: {
    addressPrefix: subnets[0].prefix
    routeTable: {
      id: rt.id
    }
  }
}

// Create VNet peering - spoke to hub (will be created in this subscription only)
resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: '${vnetName}-to-${hubVnetName}-peering'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: true // use hub's gateway/firewall for outbound
    remoteVirtualNetwork: {
      id: subscriptionResourceId(hubSubscriptionId, 'Microsoft.Network/virtualNetworks', hubVnetName)
    }
  }
  dependsOn: []
}

output vnetId string = vnetModule.outputs.vnetId
output subnetIds array = vnetModule.outputs.subnetIds
output routeTableId string = rt.id
output peeringId string = spokeToHubPeering.id
