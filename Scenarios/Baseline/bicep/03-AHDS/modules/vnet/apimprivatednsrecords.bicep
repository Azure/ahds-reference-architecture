// Paramters
param apimName                  string
param RG                        string

// Defining API<
resource apim 'Microsoft.ApiManagement/service@2020-12-01' existing = {
  name: apimName
  scope: resourceGroup(RG)
}

// Creating APIM DNS Record
resource gatewayRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: 'azure-api.net/${apimName}'
  properties: {
    aRecords: [
      {
        ipv4Address: apim.properties.privateIPAddresses[0]
      }
    ]
    ttl: 36000
  }
}

// Creating APIM Portal DNS Record
resource portalRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: 'portal.azure-api.net/${apimName}'
  properties: {
    aRecords: [
      {
        ipv4Address: apim.properties.privateIPAddresses[0]
      }
    ]
    ttl: 36000
  }
}

// Creating APIM Developer DNS Record
resource developerRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: 'developer.azure-api.net/${apimName}'
  properties: {
    aRecords: [
      {
        ipv4Address: apim.properties.privateIPAddresses[0]
      }
    ]
    ttl: 36000
  }
}

// Creating APIM Magements DNS Record
resource managementRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: 'management.azure-api.net/${apimName}'
  properties: {
    aRecords: [
      {
        ipv4Address: apim.properties.privateIPAddresses[0]
      }
    ]
    ttl: 36000
  }
}

// Creating APIM SCM DNS Record
resource scmRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: 'scm.azure-api.net/${apimName}'
  properties: {
    aRecords: [
      {
        ipv4Address: apim.properties.privateIPAddresses[0]
      }
    ]
    ttl: 36000
  }
}
