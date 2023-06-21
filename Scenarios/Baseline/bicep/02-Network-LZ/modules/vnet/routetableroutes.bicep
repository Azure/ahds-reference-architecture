// Parameters
param routetableName string
param routeName string
param properties object

// Creating Route Table Entries
resource rtroutes 'Microsoft.Network/routeTables/routes@2020-11-01'  = {
  name: '${routetableName}/${routeName}'
  properties: properties
}
