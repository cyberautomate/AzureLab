@description('Standalone deployment for VPN Gateway')
param location string = resourceGroup().location
param vnetName string = 'hub-vnet'
param gatewayName string = 'hub-vpngw'
param publicIpName string = 'hub-vpngw-pip'
param gatewaySku string = 'VpnGw1'
@description('Point-to-Site VPN configuration object including authenticationType, aadTenantId, aadAudience, clientAddressPool, vpnClientProtocols')
param vpnP2S object = {
  authenticationType: 'AzureAD'
  aadTenantId: ''
  aadAudience: ''
  clientAddressPool: '172.16.201.0/24'
  vpnClientProtocols: [ 'OpenVPN' ]
}

module vpnGateway '../modules/vpnGateway.bicep' = {
  name: 'vpnGatewayModule'
  params: {
    gatewayName: gatewayName
    location: location
    publicIpName: publicIpName
    gatewaySku: gatewaySku
    vnetName: vnetName
    vpnP2S: vpnP2S
  }
}

output gatewayId string = vpnGateway.outputs.gatewayId
output gatewayPublicIp string = vpnGateway.outputs.gatewayPublicIp
