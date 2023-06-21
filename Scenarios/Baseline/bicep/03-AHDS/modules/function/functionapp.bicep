// Parameters
param functionAppName string
param location string
param hostingPlanName string
param appInsightsInstrumentationKey string
param functionContentShareName string
param storageAccountName string
param fnIdentityId string
param VNetIntegrationSubnetID string
param kvname string
param authenticationType string


@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 365

@description('Optional. Resource identifier of log analytics.')
param diagnosticWorkspaceId string

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
param diagnosticSettingsName string = '${functionAppName}-diagnosticSettings-001'

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

var runtime  = 'dotnet'
var repourl  = 'https://github.com/microsoft/fhir-loader'

// Defining App Service Host Plan
resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' existing = {
  name: hostingPlanName
}

// Defining Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: storageAccountName
 //scope: resourceGroup(subscription().subscriptionId, RG)
}


// Creating File Share at Storage Account
resource functionContentShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' = {
  name: '${storageAccount.name}/default/${functionContentShareName}'
}

// Creating Function App
resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities:{
      '${fnIdentityId}' : {}
    }
  }
  properties: {
    reserved: false
    serverFarmId: hostingPlan.id
    virtualNetworkSubnetId: VNetIntegrationSubnetID
    keyVaultReferenceIdentity: fnIdentityId
    siteConfig: {
      vnetRouteAllEnabled: true
      functionsRuntimeScaleMonitoringEnabled: true
      http20Enabled: false
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
         // value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: runtime
        }
        {
          name: 'AzureWebJobs.ImportBundleBlobTrigger.Disabled'
          value: '1'
        }
        {
          name: 'AzureWebJobs.ImportBundleEventGrid.Disabled'
          value: '0'
        }
        {
          name: 'FBI-TRANSFORMBUNDLES'
          value: 'true'
        }
        {
          name: 'FBI-POOLEDCON-MAXCONNECTIONS'
          value: '20'
        }
        {
          name: 'FBI-POISONQUEUE-TIMER-CRON'
          value: '0 */2 * * * *'
        }
        {
          name: 'FBI-STORAGEACCT'
          value: '@Microsoft.KeyVault(VaultName=${kvname};SecretName=FBI-STORAGEACCT)'
        }
        {
          name: 'FS-URL'
          value: '@Microsoft.KeyVault(VaultName=${kvname};SecretName=FS-URL)'
        }
        {
          name: 'FS-TENANT-NAME'
          value: '@Microsoft.KeyVault(VaultName=${kvname};SecretName=FS-TENANT-NAME)'
        }
        {
          name: 'FS-RESOURCE'
          value: '@Microsoft.KeyVault(VaultName=${kvname};SecretName=FS-RESOURCE)'
        }

        {
          name: 'WEBSITE_CONTENTOVERVNET'
          value: '1'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: functionContentShareName
        }
        {
        name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
        value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
        name: 'FS-ISMSI'
        value: authenticationType == 'managedIdentity' ? 'true' : 'false'
        }
        {
          name: 'AzureFunctionsJobHost__functionTimeout'
          value: '23:00:00'
        }
        {
          name: 'FS-CLIENT-ID'
          value: authenticationType == 'servicePrincipal' ? '@Microsoft.KeyVault(VaultName=${kvname};SecretName=FS-CLIENT-ID)' : ''
        }
        {
          name: 'FS-SECRET'
          value: authenticationType == 'servicePrincipal' ? '@Microsoft.KeyVault(VaultName=${kvname};SecretName=FS-SECRET)' : ''
        }
      ]
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'

    }

    httpsOnly: true
    redundancyMode: 'None'
  }
}



// Deploing Function App Code from GitHub RepoURL
resource functiondeploy 'Microsoft.Web/sites/sourcecontrols@2022-03-01' = {
  name: 'web'
  kind: 'sourcecontrols'
  parent: functionApp
  properties: {
    branch: 'main'
    isManualIntegration: true
    repoUrl: repourl
  }
}

// Defining Diagnostic Settings for Function App
resource functionApp_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingsName
  properties: {
    workspaceId: diagnosticWorkspaceId
    metrics: diagnosticsMetrics
    logs: diagnosticsLogs
  }
  scope: functionApp
}


// Outputs
output fnappidentity string = functionApp.identity.principalId
output fnappid string = functionApp.id
