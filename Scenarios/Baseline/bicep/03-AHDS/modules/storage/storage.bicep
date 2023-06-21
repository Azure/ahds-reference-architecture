// Parameters
@description('Storage Account type')
@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_LRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
param storageAccountType string
param location string
param storageAccountName string

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 365

@description('Optional. Resource ID of the diagnostic log analytics workspace.')
param diagnosticWorkspaceId string

@description('Optional. The name of metrics that will be streamed.')
@allowed([
  'Transaction'
])
param diagnosticMetricsToEnable array = [
  'Transaction'
]
@description('Optional. The name of the diagnostic setting, if deployed.')
param diagnosticSettingsName string = '${storageAccountName}-diagnosticSettings-001'

// Variables
var diagnosticsMetrics = [for metric in diagnosticMetricsToEnable: {
  category: metric
  timeGrain: null
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]

// Creating Storage Account
resource sa 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {
    
  }
  resource queueService 'queueServices' = {
    name: 'default'
  }
}



// Variable
var storagecnnstrng = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${sa.listKeys().keys[0].value}'

// Defining Storage Account diagnostic settings
resource storageAccount_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingsName
  properties: {
    workspaceId: diagnosticWorkspaceId
    metrics: diagnosticsMetrics
  }
  scope: sa
}

output storageAccountName string = sa.name
output storageAccountId string = sa.id
output storagecnn string = storagecnnstrng
output storageFQDN string =sa.properties.primaryEndpoints.blob
