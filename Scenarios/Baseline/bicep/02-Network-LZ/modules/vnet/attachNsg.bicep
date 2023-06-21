param vnetName string
param subnetName string
param subnetAddressPrefix string
param nsgId string
param rtId string
param serviceep string= 'null'

resource nsgAttachment 'Microsoft.Network/virtualNetworks/subnets@2020-07-01' =  {
  name: '${vnetName}/${subnetName}'
  properties: {
    addressPrefix: subnetAddressPrefix
    networkSecurityGroup: {
      id: nsgId
    }
    routeTable: {
      id: rtId
    }
    serviceEndpoints: serviceep != 'null' ? [
      {
        service: serviceep
      }
    ] : []

    }
  }

