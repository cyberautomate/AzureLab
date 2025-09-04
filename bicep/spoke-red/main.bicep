param location string = resourceGroup().location
param tags object = {}

var ipPlan = json(loadTextContent('../ip-plan.json'))

module redVnet '../modules/vnet.bicep' = {
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

output redVnetId string = redVnet.outputs.vnetId
