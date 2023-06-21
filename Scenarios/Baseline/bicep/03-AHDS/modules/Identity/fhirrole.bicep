// Parameters
param principalId string
param fhirName string
param roleGuid string
param workspaceName string

var fhirservicename = '${workspaceName}/${fhirName}'

// defining FHIR
resource FHIR 'Microsoft.HealthcareApis/workspaces/fhirservices@2021-11-01' existing = {
  name: fhirservicename
}

// Giving FHIR Access to function PrincipalID
resource fhir_role_assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalId, roleGuid, fhirservicename)
  properties: {
    principalId: principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleGuid)
    principalType: 'ServicePrincipal'
  }
  scope: FHIR
}


