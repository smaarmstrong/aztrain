targetScope = 'tenant'

param platformMgName string
param landingZonesMgName string

resource platform 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: platformMgName
  properties: {
    displayName: 'Platform'
  }
}

resource landingZones 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: landingZonesMgName
  properties: {
    displayName: 'Landing Zones'
    details: {
      parent: {
        id: platform.id
      }
    }
  }
}
