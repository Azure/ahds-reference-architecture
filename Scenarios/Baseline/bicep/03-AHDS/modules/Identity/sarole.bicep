// Parameters
param principalId string
param storageAccountName string
param roleGuid string




resource sa 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageAccountName
}

// Giving FHIR Access to function PrincipalID
resource fhir_role_assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalId, roleGuid, storageAccountName)
  properties: {
    principalId: principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleGuid)
    principalType: 'ServicePrincipal'
  }
  scope: sa
}


