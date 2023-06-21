// Parameters
param routetableName string
param routeName string
param properties object

// Creating route entries
resource rtroutes 'Microsoft.Network/routeTables/routes@2021-02-01'  = {
  name: '${routetableName}/${routeName}'
  properties: properties
}
