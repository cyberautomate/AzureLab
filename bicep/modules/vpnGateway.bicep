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
var rawTenant    = empty(vpnP2S.?aadTenantId) ? '' : trim(vpnP2S.aadTenantId)
// Minimal GUID validation without regex (length + hyphen positions)
var isCandidateGuid = length(rawTenant) == 36 && substring(rawTenant,8,1) == '-' && substring(rawTenant,13,1) == '-' && substring(rawTenant,18,1) == '-' && substring(rawTenant,23,1) == '-'
// Treat values containing '://' as already a URL
var isUrlTenant  = contains(rawTenant, '://')
var tenantGuid   = (!isUrlTenant && isCandidateGuid) ? toLower(rawTenant) : ''
// loginEndpoint typically ends with '/' (e.g., https://login.microsoftonline.com/)
var loginBase    = environment().authentication.loginEndpoint
var tenantUrl    = !empty(rawTenant) ? (isUrlTenant ? rawTenant : (!empty(tenantGuid) ? '${loginBase}${tenantGuid}/' : rawTenant)) : ''
var p2sTenant    = tenantUrl
var p2sAudience  = empty(vpnP2S.?aadAudience) ? '' : vpnP2S.aadAudience
var p2sPool      = empty(vpnP2S.?clientAddressPool) ? '172.16.201.0/24' : vpnP2S.clientAddressPool
var p2sProtocols = empty(vpnP2S.?vpnClientProtocols) ? [ 'OpenVPN' ] : vpnP2S.vpnClientProtocols
// Derive issuer if GUID known
var p2sIssuer    = !empty(tenantGuid) ? 'https://sts.windows.net/${tenantGuid}/' : ''

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
      tier: gatewaySku
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
      aadIssuer: !empty(p2sIssuer) ? p2sIssuer : null
    } : null
  }
}

output gatewayId string = gateway.id
output gatewayPublicIp string = publicIp.id
