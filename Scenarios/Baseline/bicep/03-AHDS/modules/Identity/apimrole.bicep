// Parameters
param principalId string
param roleGuid string
param apimName string

// defining APIM
resource apim 'Microsoft.ApiManagement/service@2022-04-01-preview' existing = {
  name: apimName
}

// Giving APIM Access to a PrincipalID
resource role_assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalId, roleGuid, apimName)
  properties: {
    principalId: principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleGuid)
    principalType: 'ServicePrincipal'
  }
  scope: apim
}
