// Parameters
param privateDnsZoneName string
param vnetId string
param linkName string = ''

// Variables
var linkFullName = linkName == '' ? '${privateDnsZoneName}/${privateDnsZoneName}-link-hub' : '${privateDnsZoneName}/${privateDnsZoneName}-${linkName}'

// Creating Virtual Network LInk
resource dnshublink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: linkFullName
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}
