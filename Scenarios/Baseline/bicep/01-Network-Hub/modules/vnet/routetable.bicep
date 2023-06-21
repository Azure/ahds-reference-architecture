// Parameters
param rtName string
param location string = resourceGroup().location

// Creating Route Table
resource rt 'Microsoft.Network/routeTables@2021-02-01' = {
  name: rtName
  location: location
}

// Output
output routetableID string = rt.id
