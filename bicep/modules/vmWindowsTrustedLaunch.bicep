@description('Module to deploy a Windows Trusted Launch VM (Gen2) with NIC and OS disk settings')
param vmName string
param location string = resourceGroup().location
param vmSize string
param adminUsername string
@secure()
param adminPassword string
param vnetName string
param subnetName string
param enableAcceleratedNetworking bool = true
param osDiskType string = 'StandardSSD_LRS'
param osDiskDeleteOption bool = true
param availabilityZone string = ''
param imagePublisher string
param imageOffer string
param imageSku string
param imageVersion string = 'latest'
param licenseType string = 'Windows_Server'

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  parent: vnet
  name: subnetName
}

// Network interface
resource nic 'Microsoft.Network/networkInterfaces@2021-08-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    enableAcceleratedNetworking: enableAcceleratedNetworking
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// Enable accelerated networking if supported
// Virtual machine
resource vm 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: vmName
  location: location
  zones: availabilityZone == '' ? [] : [availabilityZone]
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        deleteOption: osDiskDeleteOption ? 'Delete' : 'Detach'
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    // License type (e.g., Windows_Server) - used when customer owns a license
    licenseType: licenseType
  }
  identity: {
    type: 'None'
  }
}

output nicId string = nic.id
output vmId string = vm.id
