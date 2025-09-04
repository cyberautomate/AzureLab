param location string = resourceGroup().location
param tags object = {}

var ipPlan = json(loadTextContent('../ip-plan.json'))

module blueVnet '../modules/vnet.bicep' = {
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

output blueVnetId string = blueVnet.outputs.vnetId
