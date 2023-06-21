// Parameters
param principalId string
param vaultName string

// Variables
//var roleGuid = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
var roleGuid ='4633458b-17de-408a-b874-0445c86b69e6'

// Defining Key Vault
resource keyvault 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: vaultName

}

// Giving Access to Identity at Key Vault
resource role_assignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, principalId, roleGuid)
  properties: {
    principalId: principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleGuid)
  }
  scope: keyvault
}
