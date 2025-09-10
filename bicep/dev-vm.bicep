@description('Deploy devSVR Windows Trusted Launch VM into existing dev resource group')
param location string = 'westus2'
param vmName string = 'devSVR'
param vmSize string = 'Standard_B2als_v2'
param adminUsername string = 'chief'
@secure()
param adminPassword string
param vnetName string = 'labblue-spoke-vnet'
param subnetName string = 'default'
param availabilityZone string = ''

module vmModule 'modules/vmWindowsTrustedLaunch.bicep' = {
  name: 'devVM'
  params: {
    vmName: vmName
    location: location
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    vnetName: vnetName
    subnetName: subnetName
    enableAcceleratedNetworking: true
    osDiskType: 'StandardSSD_LRS'
    osDiskDeleteOption: true
    availabilityZone: availabilityZone
    imagePublisher: 'MicrosoftWindowsServer'
    imageOffer: 'WindowsServer'
    imageSku: '2025-datacenter-gen2'
    imageVersion: 'latest'
    licenseType: 'Windows_Server'
  }
}

output vmId string = vmModule.outputs.vmId
output nicId string = vmModule.outputs.nicId
