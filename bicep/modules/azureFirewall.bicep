@description('Azure Firewall module supporting Basic (with management subnet), Standard, Premium tiers')
param firewallName string
param location string
// resourceGroup is not required; module will use the current deployment resource group
param publicIpName string
@description('Public IP name for management interface (Basic tier only). If not supplied for Basic tier, one will be auto-named.')
param managementPublicIpName string = ''
param virtualNetworkName string
@description('Data plane subnet name for firewall')
param subnetName string = 'AzureFirewallSubnet'
@description('Management subnet name (required for Basic tier)')
param managementSubnetName string = 'AzureFirewallManagementSubnet'
@description('Firewall tier: Basic | Standard | Premium')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param firewallTier string = 'Basic'
param tags object = {}
@description('Optional Point-to-Site client address pool CIDR to allow through firewall (adds simple allow network rule collection).')
param p2sAddressPool string = ''

// Public IP for firewall (data plane)
resource publicIp 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Management public IP (Basic tier requirement for management IP configuration)
resource mgmtPublicIp 'Microsoft.Network/publicIPAddresses@2022-07-01' = if (firewallTier == 'Basic') {
  name: empty(managementPublicIpName) ? '${publicIpName}-mgmt' : managementPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2022-05-01' = {
  name: firewallName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: firewallTier
    }
    ipConfigurations: [
      {
        name: 'azureFirewallIpConfiguration'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    // For Basic tier, supply separate management IP configuration
    managementIpConfiguration: firewallTier == 'Basic'
      ? {
          name: 'azureFirewallMgmtIpConfiguration'
          properties: {
            subnet: {
              id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, managementSubnetName)
            }
            publicIPAddress: {
              id: mgmtPublicIp.id
            }
          }
        }
      : null
    networkRuleCollections: empty(p2sAddressPool)
      ? []
      : [
          {
            name: 'allow-p2s'
            properties: {
              priority: 200
              action: {
                type: 'Allow'
              }
              rules: [
                {
                  name: 'allow-p2s-any'
                  sourceAddresses: [p2sAddressPool]
                  destinationAddresses: ['*']
                  destinationPorts: ['*']
                  protocols: ['Any']
                }
              ]
            }
          }
        ]
  }
}

output firewallId string = firewall.id
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPublicIp string = publicIp.id
output firewallManagementPublicIp string = firewallTier == 'Basic' ? mgmtPublicIp.id : ''
