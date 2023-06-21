targetScope = 'subscription'
// Parameters
param rgHubName string
param resourceSuffix string
param rgName string
param keyVaultPrivateEndpointName string
param acrPrivateEndpointName string
param functionAppPrivateEndpointName string
param saPrivateEndpointName string
param vnetName string
param subnetName string
param APIMsubnetName string
param VNetIntegrationSubnetName string
param APIMName string
param privateDNSZoneSAfileName string
param privateDNSZoneSAtableName string
param privateDNSZoneSAqueueName string
param privateDNSZoneACRName string
param privateDNSZoneKVName string
param privateDNSZoneSAName string
param privateDNSZoneFunctionAppName string
param privateDNSZoneFHIRName string
param acrName string = 'eslzacr${uniqueString('acrvws', utcNow('u'))}'
param keyvaultName string = 'eslz-kv-${uniqueString('acrvws', utcNow('u'))}'
param storageAccountName string = 'eslzsa${uniqueString('ahds', utcNow('u'))}'
param storageAccountType string
param location string = deployment().location
param appGatewayName string
param appGatewaySubnetName string
param availabilityZones array
param appGwyAutoScale object
param appGatewayFQDN string
param primaryBackendEndFQDN string
@allowed([ 'managedIdentity', 'servicePrincipal' ])
@description('Type of FHIR instance to integrate the loader with.')
param authenticationType string = 'managedIdentity'
@description('Set to selfsigned if self signed certificates should be used for the Application Gateway. Set to custom and copy the pfx file to vnet/certs/appgw.pfx if custom certificates are to be used')
param appGatewayCertType string
@secure()
param certPassword string
param containerNames array = [
  'bundles'
  'ndjson'
  'zip'
  'export'
  'export-trigger'
]



param hostingPlanName string
param fhirName string
param workspaceName string = 'eslzwks${uniqueString('workspacevws', utcNow('u'))}'
param functionAppName string
param ApiUrlPath string



// Variables
//var acrName = 'eslzacr${uniqueString(rgName, deployment().name)}'
//var keyvaultName = 'eslz-kv-${uniqueString(rgName, deployment().name)}'
var storageFQDN = '${storageAccountName}.blob.core.windows.net'
var audience = 'https://${workspaceName}-${fhirName}.fhir.azurehealthcareapis.com'
var functionContentShareName = 'function'

// Defining Log Analitics Workspace
//logAnalyticsWorkspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  scope: resourceGroup(rgHubName)
  name: 'log-${resourceSuffix}'
}

// Defining appInsights
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  scope: resourceGroup(rgHubName)
  name: 'appi-${resourceSuffix}'
}

// Defining Resource Groupt
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: rgName
}

// Defining Private Endpoint Subnet
resource servicesSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: '${vnetName}/${subnetName}'
}

// Defining Integration Subnet
resource VNetIntegrationSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: '${vnetName}/${VNetIntegrationSubnetName}'
}

// Creating Container Registry
module acr 'modules/acr/acr.bicep' = {
  scope: resourceGroup(rg.name)
  name: acrName
  params: {
    location: location
    acrName: acrName
    acrSkuName: 'Premium'
    diagnosticWorkspaceId: logAnalyticsWorkspace.id
  }
}

// Creating Private Endpoint for ACR
module privateEndpointAcr 'modules/vnet/privateendpoint.bicep' = {
  scope: resourceGroup(rg.name)
  name: acrPrivateEndpointName
  params: {
    location: location
    groupIds: [
      'registry'
    ]
    privateEndpointName: acrPrivateEndpointName
    privatelinkConnName: '${acrPrivateEndpointName}-conn'
    resourceId: acr.outputs.acrid
    subnetid: servicesSubnet.id
  }
}

// Defining Private DNS Zone for ACR
resource privateDNSZoneACR 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: resourceGroup(rg.name)
  name: privateDNSZoneACRName
}

// Creating Private DNS Zone settings for ACR Private Endpoint
module privateEndpointACRDNSSetting 'modules/vnet/privatedns.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'acr-pvtep-dns'
  params: {
    privateDNSZoneId: privateDNSZoneACR.id
    privateEndpointName: privateEndpointAcr.name
  }
}

// Creating Key Vault
module keyvault 'modules/keyvault/keyvault.bicep' = {
  scope: resourceGroup(rg.name)
  name: keyvaultName
  params: {
    location: location
    keyVaultsku: 'Standard'
    name: keyvaultName
    tenantId: subscription().tenantId
    networkAction: 'Deny'
    diagnosticWorkspaceId: logAnalyticsWorkspace.id
  }
}

// Creating Private Endpoint Key Vault
module privateEndpointKeyVault 'modules/vnet/privateendpoint.bicep' = {
  scope: resourceGroup(rg.name)
  name: keyVaultPrivateEndpointName
  params: {
    location: location
    groupIds: [
      'Vault'
    ]
    privateEndpointName: keyVaultPrivateEndpointName
    privatelinkConnName: '${keyVaultPrivateEndpointName}-conn'
    resourceId: keyvault.outputs.keyvaultId
    subnetid: servicesSubnet.id
  }
}

// Defining Key Vault Private DNS Zone
resource privateDNSZoneKV 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: resourceGroup(rg.name)
  name: privateDNSZoneKVName
}

// Creating Key Vault Private DNS Settings for Private DNS Zone
module privateEndpointKVDNSSetting 'modules/vnet/privatedns.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'kv-pvtep-dns'
  params: {
    privateDNSZoneId: privateDNSZoneKV.id
    privateEndpointName: privateEndpointKeyVault.name
  }
}

// Creating Storage Account for FIHRs, Functions, App Services in general
module storage 'modules/storage/storage.bicep' = {
  scope: resourceGroup(rg.name)
  name: storageAccountName
  params: {
    location: location
    storageAccountName: storageAccountName
    storageAccountType: storageAccountType
    diagnosticWorkspaceId: logAnalyticsWorkspace.id
  }
}

// Creating Private Endpoint for Storage Account Blob
module privateEndpointSA 'modules/vnet/privateendpoint.bicep' = {
  scope: resourceGroup(rg.name)
  name: saPrivateEndpointName
  params: {
    location: location
    groupIds: [
      'blob'
    ]
    privateEndpointName: saPrivateEndpointName
    privatelinkConnName: '${saPrivateEndpointName}-conn'
    resourceId: storage.outputs.storageAccountId
    subnetid: servicesSubnet.id
  }
}

// Defining Storage Account Private DNS Zone Blob
resource privateDNSZoneSA 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: resourceGroup(rg.name)
  name: privateDNSZoneSAName
}

// Creating Private Endpoint Storage Account Blob
module privateEndpointSADNSSetting 'modules/vnet/privatedns.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'sa-pvtep-dns'
  params: {
    privateDNSZoneId: privateDNSZoneSA.id
    privateEndpointName: privateEndpointSA.name
  }
}

// Creating Private Endpoint for Storage Account File
module privateEndpointSAfile 'modules/vnet/privateendpoint.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${saPrivateEndpointName}-file'
  params: {
    location: location
    groupIds: [
      'file'
    ]
    privateEndpointName: '${saPrivateEndpointName}-file'
    privatelinkConnName: '${saPrivateEndpointName}-file-conn'
    resourceId: storage.outputs.storageAccountId
    subnetid: servicesSubnet.id
  }
}

// Defining Storage Account Private DNS Zone File
resource privateDNSZoneSAfile 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: resourceGroup(rg.name)
  name: privateDNSZoneSAfileName
}

// Creating Private Endpoint DNS Settings for Storage Account File
module privateEndpointSAfileDNSSetting 'modules/vnet/privatedns.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'sa-file-pvtep-dns'
  params: {
    privateDNSZoneId: privateDNSZoneSAfile.id
    privateEndpointName: privateEndpointSAfile.name
  }
}

// Creating Private Endpoint for Storage Account Table
module privateEndpointSAtable 'modules/vnet/privateendpoint.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${saPrivateEndpointName}-table'
  params: {
    location: location
    groupIds: [
      'table'
    ]
    privateEndpointName: '${saPrivateEndpointName}-table'
    privatelinkConnName: '${saPrivateEndpointName}-table-conn'
    resourceId: storage.outputs.storageAccountId
    subnetid: servicesSubnet.id
  }
}

// Defining Storage Account Private DNS Zone Table
resource privateDNSZoneSAtable 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: resourceGroup(rg.name)
  name: privateDNSZoneSAtableName
}

// Creating Private Endpoint DNS Settings for Storage Account Table
module privateEndpointSAtableDNSSetting 'modules/vnet/privatedns.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'sa-table-pvtep-dns'
  params: {
    privateDNSZoneId: privateDNSZoneSAtable.id
    privateEndpointName: privateEndpointSAtable.name
  }
}

// Creating Private Endpoint for Storage Account Queue
module privateEndpointSAqueue 'modules/vnet/privateendpoint.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${saPrivateEndpointName}-queue'
  params: {
    location: location
    groupIds: [
      'queue'
    ]
    privateEndpointName: '${saPrivateEndpointName}-queue'
    privatelinkConnName: '${saPrivateEndpointName}-queue-conn'
    resourceId: storage.outputs.storageAccountId
    subnetid: servicesSubnet.id
  }
}

// Defining Storage Account Private DNS Zone Queue
resource privateDNSZoneSAqueue 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: resourceGroup(rg.name)
  name: privateDNSZoneSAqueueName
}

// Creating Private Endpoint DNS Settings for Storage Account Queue
module privateEndpointSAqueueDNSSetting 'modules/vnet/privatedns.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'sa-queue-pvtep-dns'
  params: {
    privateDNSZoneId: privateDNSZoneSAqueue.id
    privateEndpointName: privateEndpointSAqueue.name
  }
}

// APIM
// Defining APIM Subnet
resource APIMSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: '${vnetName}/${APIMsubnetName}'
}

// Creating APIM
module apimModule 'modules/apim/apim.bicep' = {
  name: 'apimDeploy'
  scope: resourceGroup(rg.name)
  params: {
    apimName: APIMName
    apimSubnetId: APIMSubnet.id
    location: location
    appInsightsName: appInsights.name
    appInsightsId: appInsights.id
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
    diagnosticWorkspaceId: logAnalyticsWorkspace.id
  }
}

// Adding APIM DNS Records
module apimDNSRecords 'modules/vnet/apimprivatednsrecords.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'apimDNSRecords'
  params: {
    RG: rg.name
    apimName: apimModule.outputs.apimName
  }
}

// AppGW
// Create Public IP for Application Gateway
module publicipappgw 'modules/vnet/publicip.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'APPGW-PIP'
  params: {
    availabilityZones: availabilityZones
    location: location
    publicipName: 'APPGW-PIP'
    publicipproperties: {
      publicIPAllocationMethod: 'Static'
    }
    publicipsku: {
      name: 'Standard'
      tier: 'Regional'
    }
    diagnosticWorkspaceId: logAnalyticsWorkspace.id
  }
}

// Defining Application Gateway Subnet
resource appgwSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: '${vnetName}/${appGatewaySubnetName}'
}

// Creating Application Gateway Identity (used for AppGW access Key Vault to load Certificate)
module appgwIdentity 'modules/Identity/userassigned.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'appgwIdentity'
  params: {
    location: location
    identityName: 'appgwIdentity'
  }
}

// Giving Access to Key Vault for Application Gateway Identity to read Keys, Secrets, Certificates
module kvrole 'modules/Identity/kvrole.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'kvrole'
  params: {
    principalId: appgwIdentity.outputs.azidentity.properties.principalId
    roleGuid: 'f25e0fa2-a7c8-4377-a976-54943a77a395' //Key Vault Contributor
    keyvaultName: keyvaultName
  }
}




// Generating/Loading certificate to Azure Key Vault (Depending in the parameters it can load or generete a new Self-Signed certificate)
module certificate 'modules/vnet/certificate.bicep' = {
  name: 'certificate'
  scope: resourceGroup(rg.name)
  params: {
    managedIdentity: appgwIdentity.outputs.azidentity
    keyVaultName: keyvaultName
    location: location
    appGatewayFQDN: appGatewayFQDN
    appGatewayCertType: appGatewayCertType
    certPassword: certPassword
  }
  dependsOn: [
    kvrole
  ]
}

// Creating Application Gateway (This resource will only be created after APIM API Import finishes)
module appgw 'modules/vnet/appgw.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'appgw'
  params: {
    appGwyAutoScale: appGwyAutoScale
    availabilityZones: availabilityZones
    location: location
    appgwname: appGatewayName
    appgwpip: publicipappgw.outputs.publicipId
    subnetid: appgwSubnet.id
    appGatewayIdentityId: appgwIdentity.outputs.identityid
    appGatewayFQDN: appGatewayFQDN
    keyVaultSecretId: certificate.outputs.secretUri
    primaryBackendEndFQDN: primaryBackendEndFQDN
    diagnosticWorkspaceId: logAnalyticsWorkspace.id
    storageFQDN: storageFQDN
  }
  dependsOn: [
   apimImportAPI
  ]
}

// Create FHIR service
// Giving Access to AppGW Identity to APIM, since we are re-using the same MI to load the APIM FHIR API at APIM
module apimrole 'modules/Identity/apimrole.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'apimrole'
  params: {
    principalId: appgwIdentity.outputs.azidentity.properties.principalId
    roleGuid: '312a565d-c81f-4fd8-895a-4e21e48d571c' //APIM Contributor
    apimName: apimModule.outputs.apimName
  }
}

module sarole 'modules/Identity/sarole.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'sarole'
  params: {
    principalId: appgwIdentity.outputs.azidentity.properties.principalId
    roleGuid: '17d1049b-9a84-46fb-8f53-869881c3d3ab' //APIM Contributor
    storageAccountName: storage.name
  }
}

// Creating FHIR Service
module fhir 'modules/ahds/fhirservice.bicep' = {
  scope: resourceGroup(rg.name)
  name: fhirName
  params: {
    fhirName: fhirName
    workspaceName: workspaceName
    location: location
    diagnosticWorkspaceId: logAnalyticsWorkspace.id
  }
}



// Creating FHIR Private Endpoint
module privateEndpointFHIR 'modules/vnet/privateendpoint.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'fhir-pvtep'
  params: {
    location: location
    groupIds: [
      'healthcareworkspace'
    ]
    privateEndpointName: 'fhir-pvtep'
    privatelinkConnName: 'fhir-pvtep-conn'
    resourceId: fhir.outputs.fhirWorkspaceID
    subnetid: servicesSubnet.id
  }
}

// Defining FHIR Private DNS Zone for FHIR
resource privateDNSZoneFHIR 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: resourceGroup(rg.name)
  name: privateDNSZoneFHIRName
}

// Creating Private DNS Setting for FHIR Private DNS Settings
module privateEndpointFHIRDNSSetting 'modules/vnet/privatedns.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'fhir-pvtep-dns'
  params: {
    privateDNSZoneId: privateDNSZoneFHIR.id
    privateEndpointName: privateEndpointFHIR.name
  }
}

// Hosting plan App Service
// Creating App Service Plan
module hostingPlan 'modules/function/hostingplan.bicep' = {
  scope: resourceGroup(rg.name)
  name: hostingPlanName
  params: {
    hostingPlanName: hostingPlanName
    location: location
    functionWorkers: 5
  }
}

// Creating Storage Container
module container 'modules/storage/container.bicep' = [for name in containerNames: {
  scope: resourceGroup(rg.name)
  name: '${name}'
  params: {
    containername: name
    storageAccountName: storage.outputs.storageAccountName
  }
}]

// Creating ndjsonqueue Storage Queue
module ndjsonqueue 'modules/storage/queue.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'ndjsonqueue'
  params: {
    queueName: 'ndjsonqueue'
    storageAccountName: storage.outputs.storageAccountName
  }
}

module bundlequeue 'modules/storage/queue.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'bundlequeue'
  params: {
    queueName: 'bundlequeue'
    storageAccountName: storage.outputs.storageAccountName
  }
}



// Creating Storage file share
module functioncontentfileshare 'modules/storage/fileshare.bicep' = {
  scope: resourceGroup(rg.name)
  name: functionContentShareName
  params: {
    storageAccountName: storage.outputs.storageAccountName
    functionContentShareName: functionContentShareName
  }
}

// Creating KeyVault Secret FS-URL
module fsurlkvsecret 'modules/keyvault/kvsecrets.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'fsurl'
  params: {
    kvname: keyvault.outputs.keyvaultName
    secretName: 'FS-URL'
    secretValue: audience
  }
}

// Creating KeyVault Secret FS-TENANT-NAME
module tenantkvsecret 'modules/keyvault/kvsecrets.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'fstenant'
  params: {
    kvname: keyvault.outputs.keyvaultName
    secretName: 'FS-TENANT-NAME'
    secretValue: subscription().tenantId
  }
}

// Creating KeyVault Secret FS-RESOURCE
module fsreskvsecret 'modules/keyvault/kvsecrets.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'fsresource'
  params: {
    kvname: keyvault.outputs.keyvaultName
    secretName: 'FS-RESOURCE'
    secretValue: audience
  }
}

// Creating KeyVault Secret FS-STORAGEACCT
module sakvsecret 'modules/keyvault/kvsecrets.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'fsstorage'
  params: {
    kvname: keyvault.outputs.keyvaultName
    secretName: 'FBI-STORAGEACCT'
    secretValue: storage.outputs.storagecnn
  }
}

// Creating user assigned for fhirloaderid
module fnIdentity 'modules/Identity/userassigned.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'fnIdentity'
  params: {
    location: location
    identityName: 'fhirloaderid'
  }
}

// Giving access to KeyVault Access for fhirloaderid
module kvaccess 'modules/keyvault/keyvaultaccess.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'kvaultAccess'
  params: {
    keyvaultManagedIdentityObjectId: fnIdentity.outputs.principalId
    vaultName: keyvault.outputs.keyvaultName
  }
}

// Giving access to KeyVault Access for fhirloaderid
module fnvaultRole 'modules/Identity/kvaccess.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'fnvaultRole'
  params: {
    principalId: fnIdentity.outputs.principalId
    vaultName: keyvault.outputs.keyvaultName
  }
}

// Importing FHIR at APIM (This is using deployment script, it will load the Swagger API definition from GitHub)
module apimImportAPI 'modules/apim/api-deploymentScript.bicep' = {
  name: 'apimImportAPI'
  scope: resourceGroup(rg.name)
  params: {
    managedIdentity: appgwIdentity.outputs.azidentity
    location: location
    RGName: rg.name
    APIMName: apimModule.outputs.apimName
    serviceUrl: fhir.outputs.serviceHost
    APIFormat: 'Swagger'
    APIpath: 'fhir'
    ApiUrlPath: ApiUrlPath
  }
  dependsOn: [
    apimrole
  ]
}

// FunctionApp
// Creating Function App
module functionApp 'modules/function/functionapp.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'functionApp'
  params: {
    functionAppName: functionAppName
    location: location
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
    storageAccountName: storage.outputs.storageAccountName
    VNetIntegrationSubnetID: VNetIntegrationSubnet.id
    functionContentShareName: functionContentShareName
    hostingPlanName: hostingPlan.outputs.serverfarmname
    kvname: keyvault.outputs.keyvaultName
    fnIdentityId: fnIdentity.outputs.identityid
    diagnosticWorkspaceId: logAnalyticsWorkspace.id
    authenticationType: authenticationType
  }
  dependsOn: [
    kvaccess
    fnvaultRole
    functioncontentfileshare
    fsurlkvsecret
    tenantkvsecret
    fsreskvsecret
    sakvsecret
  ]
}

// Creating role for Function App identity on FHIR
module fhirrole 'modules/Identity/fhirrole.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'fhirrole'
  params: {
    principalId: functionApp.outputs.fnappidentity
    roleGuid: '5a1fc7df-4bf1-4951-a576-89034ee01acd'
    fhirName: fhir.name
    workspaceName: workspaceName
  }
}

// Creating Function App Private Endpoint
module privateEndpointFunctionApp 'modules/vnet/privateendpoint.bicep' = {
  scope: resourceGroup(rg.name)
  name: functionAppPrivateEndpointName
  params: {
    location: location
    groupIds: [
      'sites'
    ]
    privateEndpointName: functionAppPrivateEndpointName
    privatelinkConnName: '${functionAppPrivateEndpointName}-conn'
    resourceId: functionApp.outputs.fnappid
    subnetid: servicesSubnet.id
  }
}

// Defining Private DNS Zone for Function App
resource privateDNSZoneFunctionApp 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: resourceGroup(rg.name)
  name: privateDNSZoneFunctionAppName
}

// Creating Function App Private endpoint DNS Settings
module privateEndpointFunctionAppDNSSetting 'modules/vnet/privatedns.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'functionApp-pvtep-dns'
  params: {
    privateDNSZoneId: privateDNSZoneFunctionApp.id
    privateEndpointName: privateEndpointFunctionApp.name
  }
}



module bundleeventsub 'modules/storage/eventsub.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'bundlequeuesub'
  params: {
    queueName: 'bundlequeue'
    storageAccountName: storage.outputs.storageAccountName
    subjectbegins: '/blobServices/default/containers/bundles'
    subjectends: '.json'
  }
  dependsOn: [
    bundlequeue
  ]
}

module ndjsoneventsub 'modules/storage/eventsub.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'ndjsonqueuesub'
  params: {
    queueName: 'ndjsonqueue'
    storageAccountName: storage.outputs.storageAccountName
    subjectbegins: '/blobServices/default/containers/ndjson'
    subjectends: '.ndjson'
  }
  dependsOn: [
    ndjsonqueue
  ]
}

module storageNetworkUpdate 'modules/storage/sanetwork-deploymentScript.bicep' = {
  name: 'storageNetworkUpdate'
  scope: resourceGroup(rg.name)
  params: {
    managedIdentity: appgwIdentity.outputs.azidentity
    location: location
    RGName: rg.name
    subnet: appgwSubnet.id
    storageAccountName: storageAccountName
  }
  dependsOn: [
    ndjsonqueue
    bundleeventsub 
    appgw
    sarole
  ]
}


// Outputs
output acrName string = acr.name
output keyvaultName string = keyvault.name
output storageName string = storage.name
