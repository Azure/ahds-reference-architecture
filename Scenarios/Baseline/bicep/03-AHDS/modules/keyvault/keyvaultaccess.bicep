// Parameters
param keyvaultManagedIdentityObjectId string
param vaultName string

// Giving Access to MI at Key Vault
resource keyvaultaccesspolicy 'Microsoft.KeyVault/vaults/accessPolicies@2021-06-01-preview' = {
  name: '${vaultName}/add'
  properties: {
    accessPolicies: [
      {
        objectId: keyvaultManagedIdentityObjectId
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
          ]
        }
        tenantId: subscription().tenantId
      }
      /*
      {
        objectId: useraccessprincipalId
        permissions: {
          secrets: [
            'all'
          ]
          storage: [
            'all'
          ]
          keys: [
            'all'
          ]
          certificates: [
            'all'
          ]
        }
        tenantId: subscription().tenantId
      }
      */
    ]
  }
}
