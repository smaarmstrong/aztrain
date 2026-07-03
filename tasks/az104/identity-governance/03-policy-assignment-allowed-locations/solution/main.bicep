param allowedLocations array = [
  'uksouth'
  'ukwest'
]

var allowedLocationsDefId = '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'

resource assignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'allowed-locations'
  properties: {
    displayName: 'Allowed locations (UK only)'
    policyDefinitionId: allowedLocationsDefId
    parameters: {
      listOfAllowedLocations: {
        value: allowedLocations
      }
    }
  }
}
