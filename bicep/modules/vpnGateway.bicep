@description('VPN Gateway module (Virtual Network Gateway) skeleton for P2S')
param gatewayName string
param location string
param publicIpName string
@description('Virtual network name hosting the gateway')
param vnetName string
@description('Gateway subnet name')
param gatewaySubnetName string = 'GatewaySubnet'
param gatewaySku string = 'VpnGw1'
param vpnType string = 'RouteBased'
param enableBgp bool = false
@description('Point-to-Site VPN configuration object: authenticationType, aadTenantId, aadAudience, clientAddressPool, vpnClientProtocols')
param vpnP2S object = {
  authenticationType: 'AzureAD'
  aadTenantId: ''
  aadAudience: ''
  clientAddressPool: '172.16.201.0/24'
  vpnClientProtocols: [ 'OpenVPN' ]
}

// Normalize optional members to avoid runtime errors if caller omits keys (using safe access .?)
var p2sTenant    = empty(vpnP2S.?aadTenantId) ? '' : vpnP2S.aadTenantId
var p2sAudience  = empty(vpnP2S.?aadAudience) ? '' : vpnP2S.aadAudience
var p2sPool      = empty(vpnP2S.?clientAddressPool) ? '172.16.201.0/24' : vpnP2S.clientAddressPool
var p2sProtocols = empty(vpnP2S.?vpnClientProtocols) ? [ 'OpenVPN' ] : vpnP2S.vpnClientProtocols

resource publicIp 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    // Standard SKU public IPs for Virtual Network Gateway must be Static
    publicIPAllocationMethod: 'Static'
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
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, gatewaySubnetName)
          }
        }
      }
    ]
    gatewayType: 'Vpn'
    vpnType: vpnType
    sku: {
      name: gatewaySku
    }
    enableBgp: enableBgp
    // Point-to-Site configuration if audience & tenant provided
    vpnClientConfiguration: (!empty(p2sTenant) && !empty(p2sAudience)) ? {
      vpnClientAddressPool: {
        addressPrefixes: [ p2sPool ]
      }
      vpnClientProtocols: p2sProtocols
      vpnAuthenticationTypes: [ 'AAD' ]
      aadTenant: p2sTenant
      aadAudience: p2sAudience
      // Optionally specify aadIssuer if required (AAD common endpoint inferred if omitted)
    } : null
  }
}

output gatewayId string = gateway.id
output gatewayPublicIp string = publicIp.id
