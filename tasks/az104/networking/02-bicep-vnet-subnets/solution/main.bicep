param location string = resourceGroup().location

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-app'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.20.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-web'
        properties: {
          addressPrefix: '10.20.1.0/24'
        }
      }
      {
        name: 'snet-data'
        properties: {
          addressPrefix: '10.20.2.0/24'
        }
      }
    ]
  }
}

output subnetIds array = [
  resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'snet-web')
  resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'snet-data')
]
