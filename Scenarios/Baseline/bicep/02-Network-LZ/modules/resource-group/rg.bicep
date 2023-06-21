targetScope = 'subscription'
// Parameters
param location string = deployment().location
param rgName string

// Creating Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  location: location
  name: rgName
}

// Outputs
output rgId string = rg.id
output rgName string = rg.name
