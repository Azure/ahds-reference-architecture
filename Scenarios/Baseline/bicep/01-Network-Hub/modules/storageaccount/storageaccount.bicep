// Parameters
param nameSufix string

@maxLength(24)
@description('Required. Name of the Storage Account.')
param stacctname string = '${nameSufix}${uniqueString('sa-VM', utcNow('u'))}'

@description('Optional. Location for all resources.')
param location string = resourceGroup().location
@allowed([
  'Storage'
  'StorageV2'
  'BlobStorage'
  'FileStorage'
  'BlockBlobStorage'
])
@description('Optional. Type of Storage Account to create.')
param storageAccountKind string = 'StorageV2'

@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
@description('Optional. Storage Account Sku Name.')
param storageAccountSku string = 'Standard_LRS'

@allowed([
  'Hot'
  'Cool'
])
@description('Optional. Storage Account Access Tier.')
param storageAccountAccessTier string = 'Hot'

@allowed([
  'TLS1_0'
  'TLS1_1'
  'TLS1_2'
])
@description('Optional. Set the minimum TLS version on request to storage.')
param minimumTlsVersion string = 'TLS1_2'

// Create the storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: stacctname
  location: location
  kind: storageAccountKind
  sku: {
    name: storageAccountSku
  }
  properties:{
    accessTier:storageAccountAccessTier
    minimumTlsVersion:minimumTlsVersion
  }
}

// Outputs
@description('The name of the deployed storage account.')
output name string = storageAccount.name

@description('The primary blob endpoint reference if blob services are deployed.')
output primaryBlobEndpoint string = reference('Microsoft.Storage/storageAccounts/${storageAccount.name}', '2019-04-01').primaryEndpoints.blob
