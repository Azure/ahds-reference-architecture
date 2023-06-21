// Parameters
param keyVaultName string
param secretName   string

// Defining Key Vault Secret
resource keyVaultCertificate 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' existing = {
  name: '${keyVaultName}/${secretName}'
}

// Outputs
output secretUri string = keyVaultCertificate.properties.secretUriWithVersion
