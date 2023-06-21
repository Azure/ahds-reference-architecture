// Parameters
param vnetName string
param subnetName string
param properties object

// Defining vnet
resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: vnetName
}

// Creating Subnets
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = {
  name: '${vnet.name}/${subnetName}'
   properties: properties
}

// Outputs
output subnetId string = subnet.id
