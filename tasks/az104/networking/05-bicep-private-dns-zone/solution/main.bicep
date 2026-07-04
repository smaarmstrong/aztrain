param location string = resourceGroup().location

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-app'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.30.0.0/16'
      ]
    }
  }
}

resource zone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'corp.internal'
  location: 'global'
}

resource appRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: zone
  name: 'app'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: '10.30.1.10'
      }
    ]
  }
}

resource link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: zone
  name: 'link-vnet-app'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}
