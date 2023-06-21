// Parameters
param kvname string

@description('Specifies the name of the secret that you want to create.')
param secretName string

@description('Specifies the value of the secret that you want to create.')
@secure()
param secretValue string

// Defining Key Vault
resource kv 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: kvname
  //scope: resourceGroup(subscriptionId, kvResourceGroup )
}

// Adding Key Vault Secret
resource secret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: kv
  name: secretName
  properties: {
    value: secretValue
  }
}
