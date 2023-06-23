param vnetName string
param subnetName string
param nsgId string
param rtId string

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: '${vnetName}/${subnetName}'
}

module updateNSG 'attachNsg.bicep' = {
  name: 'nsgupdate'
  params: {
    rtId: rtId
    vnetName: vnetName
    subnetName: subnetName
    nsgId: nsgId
    subnetAddressPrefix: subnet.properties.addressPrefix
    serviceep: 'Microsoft.Storage'
  }

}

