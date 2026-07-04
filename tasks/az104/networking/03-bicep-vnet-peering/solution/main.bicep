param location string = resourceGroup().location

resource hub 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-hub'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }
}

resource spoke 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-spoke'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
  }
}

resource spokeToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: spoke
  name: 'spoke-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hub.id
    }
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
  }
}
