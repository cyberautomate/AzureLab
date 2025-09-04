@description('Module to create a route table with routes')
param routeTableName string
param location string
param tags object = {}
param routes array = [] // array of { name: string, addressPrefix: string, nextHopType: string, nextHopIpAddress?: string }

resource rt 'Microsoft.Network/routeTables@2022-07-01' = {
  name: routeTableName
  location: location
  tags: tags
  properties: {
    routes: [for r in routes: {
      name: r.name
      properties: {
        addressPrefix: r.addressPrefix
        nextHopType: r.nextHopType
  nextHopIpAddress: r.nextHopIpAddress
      }
    }]
  }
}

output routeTableId string = rt.id
