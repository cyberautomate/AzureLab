@description('Module to create a VNet with configurable subnets and optional delegations')
param vnetName string
param vnetAddressPrefix string
param location string
param tags object = {}
param subnets array = [] // array of objects: { name: string, prefix: string, delegation: object? }

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [for sn in subnets: {
      name: sn.name
      properties: union({ addressPrefix: sn.prefix }, sn.delegation != null ? { delegations: [sn.delegation] } : {})
    }]
  }
}

output vnetId string = vnet.id
output subnetIds array = [for sn in subnets: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, sn.name)]
