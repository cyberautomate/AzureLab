@description('VPN Gateway module (Virtual Network Gateway) skeleton for P2S')
param gatewayName string
param location string
param publicIpName string
param gatewaySku string = 'VpnGw1'
param vpnType string = 'RouteBased'
param enableBgp bool = false

resource publicIp 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource gateway 'Microsoft.Network/virtualNetworkGateways@2022-07-01' = {
  name: gatewayName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
          // subnet id will be provided by parent template
        }
      }
    ]
    gatewayType: 'Vpn'
    vpnType: vpnType
    sku: {
      name: gatewaySku
    }
    enableBgp: enableBgp
  }
}

output gatewayId string = gateway.id
output gatewayPublicIp string = publicIp.id
