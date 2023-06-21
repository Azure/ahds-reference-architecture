targetScope = 'subscription'

// Parameters
param location string = deployment().location
param rgHubName string

// Creating Resource Groupt
resource rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  location: location
  name: rgHubName
}

// Output
output rgId string = rg.id
output rgHubName string = rg.name
