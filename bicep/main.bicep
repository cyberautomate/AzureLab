@description('Main deployment that composes modules')
param namePrefix string
param environment string = 'dev'
param location string = resourceGroup().location
param tags object = {}

@description('Deploy the Blue spoke virtual network when true')
param deployBlueVnet bool = false
@description('Deploy the Red spoke virtual network when true')
param deployRedVnet bool = false

// Load IP plan for address spaces
var ipPlan = json(loadTextContent('ip-plan.json'))


module storage 'modules/storageAccount.bicep' = {
  name: 'storageModule'
  params: {
    namePrefix: namePrefix
    environment: environment
    location: location
    tags: tags
  }
}

output storageAccountId string = storage.outputs.storageAccountId
output storageAccountName string = storage.outputs.storageAccountName
output storagePrimaryEndpoints object = storage.outputs.primaryEndpoints

// Conditionally deploy Blue VNet
module blueVnet 'modules/vnet.bicep' = if (deployBlueVnet) {
  name: 'blueVnet'
  params: {
    vnetName: 'blue-vnet'
    vnetAddressPrefix: ipPlan.blue.vnetCidr
    location: location
    tags: tags
    subnets: [
      {
        name: 'blue-vm-subnet-1'
        prefix: ipPlan.blue.subnets.blueVmSubnet1
      }
      {
        name: 'blue-vm-subnet-2'
        prefix: ipPlan.blue.subnets.blueVmSubnet2
      }
      {
        name: 'blue-container-subnet'
        prefix: ipPlan.blue.subnets.blueContainerSubnet
        delegation: {
          name: 'containerDelegation'
          properties: {
            serviceName: 'Microsoft.ContainerInstance/containerGroups'
          }
        }
      }
    ]
  }
}

@description('Blue VNet resource ID (empty when not deployed)')
output blueVnetId string = deployBlueVnet ? resourceId('Microsoft.Network/virtualNetworks', 'blue-vnet') : ''

// Conditionally deploy Red VNet
module redVnet 'modules/vnet.bicep' = if (deployRedVnet) {
  name: 'redVnet'
  params: {
    vnetName: 'red-vnet'
    vnetAddressPrefix: ipPlan.red.vnetCidr
    location: location
    tags: tags
    subnets: [
      {
        name: 'red-vm-subnet-1'
        prefix: ipPlan.red.subnets.redVmSubnet1
      }
      {
        name: 'red-vm-subnet-2'
        prefix: ipPlan.red.subnets.redVmSubnet2
      }
      {
        name: 'red-container-subnet'
        prefix: ipPlan.red.subnets.redContainerSubnet
        delegation: {
          name: 'containerDelegation'
          properties: {
            serviceName: 'Microsoft.ContainerInstance/containerGroups'
          }
        }
      }
    ]
  }
}

@description('Red VNet resource ID (empty when not deployed)')
output redVnetId string = deployRedVnet ? resourceId('Microsoft.Network/virtualNetworks', 'red-vnet') : ''

