// Parameters
param privateDNSZoneName string

// Creating Private DNS Zone
resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDNSZoneName
  location: 'global'
}

// Outputs
output privateDNSZoneName string = privateDNSZone.name
output privateDNSZoneId string = privateDNSZone.id
