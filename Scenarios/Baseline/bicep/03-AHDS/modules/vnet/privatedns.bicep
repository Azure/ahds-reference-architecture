// Parameters
param privateEndpointName string
param privateDNSZoneId string

// Creating Private DNS Settings for Private Endpoint
resource privateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${privateEndpointName}/dnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDNSZoneId
        }
      }
    ]
  }
}
