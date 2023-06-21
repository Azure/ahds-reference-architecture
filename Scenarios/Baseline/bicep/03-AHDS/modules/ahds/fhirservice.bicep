// Parameters
param fhirName string
param workspaceName string
param location string = resourceGroup().location

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 365

@description('Optional. Resource ID of the diagnostic log analytics workspace. For security reasons, it is recommended to set diagnostic settings to send data to either storage account, log analytics workspace or event hub.')
param diagnosticWorkspaceId string

@description('Optional. The name of logs that will be streamed. "allLogs" includes all possible logs for the resource.')
@allowed([
  'allLogs'
  'FHIRAuditlogs'
])
param diagnosticLogCategoriesToEnable array = [
  'allLogs'
]

@description('Optional. The name of metrics that will be streamed.')
@allowed([
  'AllMetrics'
])
param diagnosticMetricsToEnable array = [
  'AllMetrics'
]

@description('Optional. The name of the diagnostic setting, if deployed.')
param diagnosticSettingsName string = '${fhirName}-diagnosticSettings-001'

// Variables
var diagnosticsLogsSpecified = [for category in filter(diagnosticLogCategoriesToEnable, item => item != 'allLogs'): {
  category: category
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]

var diagnosticsLogs = contains(diagnosticLogCategoriesToEnable, 'allLogs') ? [
  {
    categoryGroup: 'allLogs'
    enabled: true
    retentionPolicy: {
      enabled: true
      days: diagnosticLogsRetentionInDays
    }
  }
] : diagnosticsLogsSpecified

var diagnosticsMetrics = [for metric in diagnosticMetricsToEnable: {
  category: metric
  timeGrain: null
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]

var tenantId = subscription().tenantId
var fhirservicename = '${workspaceName}/${fhirName}'
var loginURL = environment().authentication.loginEndpoint
var authority = '${loginURL}${tenantId}'
var audience = 'https://${workspaceName}-${fhirName}.fhir.azurehealthcareapis.com'
var serviceHost = '${workspaceName}-${fhirName}.fhir.azurehealthcareapis.com'

// Creating FHIR Workspace
resource Workspace 'Microsoft.HealthcareApis/workspaces@2022-06-01' = {
  name: workspaceName
  location: location
  properties: {
    publicNetworkAccess: 'Disabled'
  }
}

// Creating FHIR service at Workspace
resource FHIR 'Microsoft.HealthcareApis/workspaces/fhirservices@2021-11-01' = {
  name: fhirservicename
  location: location
  kind: 'fhir-R4'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    accessPolicies: []
    authenticationConfiguration: {
      authority: authority
      audience: audience
      smartProxyEnabled: false
    }
    publicNetworkAccess: 'Disabled'
    }
    dependsOn: [
      Workspace
    ]
}

// Defining FHIR Diagnostic Settings
resource FHIR_diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = {
  name: diagnosticSettingsName
  properties: {
    workspaceId: diagnosticWorkspaceId
    metrics: diagnosticsMetrics
    logs: diagnosticsLogs
  }
  scope: FHIR
}

// Outputs
output fhirServiceURL string = audience
output fhirID string = FHIR.id
output fhirWorkspaceID string = Workspace.id
output serviceHost string = serviceHost
