param location string = resourceGroup().location
param workspaceName string
param opsEmail string

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ops-oncall-ag'
  location: 'Global'
  properties: {
    groupShortName: 'ops-ag'
    enabled: true
    emailReceivers: [
      {
        name: 'ops-email'
        emailAddress: opsEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

output workspaceId string = workspace.id
output actionGroupId string = actionGroup.id
