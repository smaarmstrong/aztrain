param vmResourceId string
param actionGroupId string
param location string = 'global'

resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'high-cpu-alert'
  location: location
  properties: {
    severity: 2
    enabled: true
    scopes: [
      vmResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCPU'
          metricNamespace: 'Microsoft.Compute/virtualMachines'
          metricName: 'Percentage CPU'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}

output alertId string = cpuAlert.id
