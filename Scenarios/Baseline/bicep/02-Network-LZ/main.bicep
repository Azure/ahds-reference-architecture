targetScope = 'subscription'

// Parameters
param rgHubName string
param rgName string
param vnetSpokeName string
param spokeVNETaddPrefixes array
param spokeSubnets array
param rtFHIRSubnetName string
param firewallIP string
param vnetHubName string
param vnetHUBRGName string
param nsgFHIRName string
param nsgAppGWName string
param rtAppGWSubnetName string
param dhcpOptions object
param location string = deployment().location
param resourceSuffix string
param appGatewaySubnetName string
param FHIRSubnetName string

// Defining logAnalyticsWorkspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  scope: resourceGroup(rgHubName)
  name: 'log-${resourceSuffix}'
}

// Creating SPOKE resource Group
module rg 'modules/resource-group/rg.bicep' = {
  name: rgName
  params: {
    rgName: rgName
    location: location
  }
}

// Creating Spoke Virtual Network
module vnetspoke 'modules/vnet/vnet.bicep' = {
  scope: resourceGroup(rg.name)
  name: vnetSpokeName
  params: {
    location: location
    vnetAddressSpace: {
      addressPrefixes: spokeVNETaddPrefixes
    }
    vnetName: vnetSpokeName
    subnets: spokeSubnets
    dhcpOptions: dhcpOptions
    diagnosticWorkspaceId: logAnalyticsWorkspace.id
  }
  dependsOn: [
    rg
  ]
}

// Creating NSG for FHIR Subnet
module nsgfhirsubnet 'modules/vnet/nsg.bicep' = {
  scope: resourceGroup(rg.name)
  name: nsgFHIRName
  params: {
    location: location
    nsgName: nsgFHIRName
    diagnosticWorkspaceId: logAnalyticsWorkspace.id
  }
}

// Creating FHIR route table
module routetable 'modules/vnet/routetable.bicep' = {
  scope: resourceGroup(rg.name)
  name: rtFHIRSubnetName
  params: {
    location: location
    rtName: rtFHIRSubnetName
  }
}

// Adding FHIR Route table entries
module routetableroutes 'modules/vnet/routetableroutes.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'FHIR-to-internet'
  params: {
    routetableName: rtFHIRSubnetName
    routeName: 'FHIR-to-internet'
    properties: {
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: firewallIP
      addressPrefix: '0.0.0.0/0'
    }
  }
  dependsOn: [
    routetable
  ]
}

// Defining HUB Virtual Network
resource vnethub 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  scope: resourceGroup(vnetHUBRGName)
  name: vnetHubName
}

// Creating VNet Peering Hub to Spoke
module vnetpeeringhub 'modules/vnet/vnetpeering.bicep' = {
  scope: resourceGroup(vnetHUBRGName)
  name: 'vnetpeeringhub'
  params: {
    peeringName: 'HUB-to-Spoke'
    vnetName: vnethub.name
    properties: {
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      remoteVirtualNetwork: {
        id: vnetspoke.outputs.vnetId
      }
    }
  }
  dependsOn: [
    vnethub
    vnetspoke
  ]
}

// Creating VNet Peering Spoke to Hub
module vnetpeeringspoke 'modules/vnet/vnetpeering.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'vnetpeeringspoke'
  params: {
    peeringName: 'Spoke-to-HUB'
    vnetName: vnetspoke.outputs.vnetName
    properties: {
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      remoteVirtualNetwork: {
        id: vnethub.id
      }
    }
  }
  dependsOn: [
    vnethub
    vnetspoke
  ]
}

// Creating Private DNS Zone for ACR
module privatednsACRZone 'modules/vnet/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsACRZone'
  params: {
    privateDNSZoneName: 'privatelink${environment().suffixes.acrLoginServer}'
  }
}

// Linking Private DNS Zone for ACR to Hub VNet
module privateDNSLinkACR 'modules/vnet/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privateDNSLinkACR'
  params: {
    privateDnsZoneName: privatednsACRZone.outputs.privateDNSZoneName
    vnetId: vnethub.id
  }
}

// Creating Private DNS Zone for Key Vault
module privatednsVaultZone 'modules/vnet/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsVaultZone'
  params: {
    privateDNSZoneName: 'privatelink.vaultcore.azure.net'
  }
}

// Linking Private DNS Zone for Key Vault to Hub VNet
module privateDNSLinkVault 'modules/vnet/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privateDNSLinkVault'
  params: {
    privateDnsZoneName: privatednsVaultZone.outputs.privateDNSZoneName
    vnetId: vnethub.id
  }
}

// Linking Private DNS Zone for Key Vault to Spoke VNet (required for AppGW to work properly to load Cert from a Private Endpoing Key Vault)
module privateDNSLinkVaultSpoke 'modules/vnet/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privateDNSLinkVaultSpoke'
  params: {
    privateDnsZoneName: privatednsVaultZone.outputs.privateDNSZoneName
    vnetId: vnetspoke.outputs.vnetId
    linkName: 'link-spoke'
  }
  dependsOn: [
    privateDNSLinkVault
  ]
}

// Creating Private DNS Zone for Storage Account Blob
module privatednsSAZone 'modules/vnet/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsSAZone'
  params: {
    privateDNSZoneName: 'privatelink.blob.${environment().suffixes.storage}'
  }
}

// Linking Private DNS Zone for Storage Account Blob to Hub VNet
module privateDNSLinkSA 'modules/vnet/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privateDNSLinkSA'
  params: {
    privateDnsZoneName: privatednsSAZone.outputs.privateDNSZoneName
    vnetId: vnethub.id
  }
}

// Creating Private DNS Zone for Storage Account File
module privatednsSAfileZone 'modules/vnet/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsSAfileZone'
  params: {
    privateDNSZoneName: 'privatelink.file.${environment().suffixes.storage}'
  }
}

// Linking Private DNS Zone for Storage Account File to Hub VNet
module privateDNSLinkSAfile 'modules/vnet/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privateDNSLinkSAfile'
  params: {
    privateDnsZoneName: privatednsSAfileZone.outputs.privateDNSZoneName
    vnetId: vnethub.id
  }
}

// Creating Private DNS Zone for Storage Account Table
module privatednsSAtableZone 'modules/vnet/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsSAtableZone'
  params: {
    privateDNSZoneName: 'privatelink.table.${environment().suffixes.storage}'
  }
}

// Linking Private DNS Zone for Storage Account Table to Hub VNet
module privateDNSLinkSAtable 'modules/vnet/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privateDNSLinkSAtable'
  params: {
    privateDnsZoneName: privatednsSAtableZone.outputs.privateDNSZoneName
    vnetId: vnethub.id
  }
}

// Creating Private DNS Zone for Storage Account Queue
module privatednsSAqueueZone 'modules/vnet/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsSAqueueZone'
  params: {
    privateDNSZoneName: 'privatelink.queue.${environment().suffixes.storage}'
  }
}

// Linking Private DNS Zone for Storage Account Queue to Hub VNet
module privateDNSLinkSAqueue 'modules/vnet/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privateDNSLinkSAqueue'
  params: {
    privateDnsZoneName: privatednsSAqueueZone.outputs.privateDNSZoneName
    vnetId: vnethub.id
  }
}

// Creating Private DNS Zone for App Service
module privatednsAppSVCZone 'modules/vnet/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsAppSVCZone'
  params: {
    privateDNSZoneName: 'privatelink.azurewebsites.net'
  }
}

// Linking Private DNS Zone for App Service to Hub VNet
module privateDNSLinkAppSVC 'modules/vnet/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privateDNSLinkAppSVC'
  params: {
    privateDnsZoneName: privatednsAppSVCZone.outputs.privateDNSZoneName
    vnetId: vnethub.id
  }
}


// APIM DNS Zones
// Creating Private DNS Zone for APIM
module privatednsazureapinet 'modules/vnet/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsazureapinet'
  params: {
    privateDNSZoneName: 'azure-api.net'
  }
}

// Linking Private DNS Zone for APIM to Hub VNet
module privatednsazureapinetLink 'modules/vnet/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsazureapinetLink'
  params: {
    privateDnsZoneName: privatednsazureapinet.outputs.privateDNSZoneName
    vnetId: vnethub.id
  }
}

// Creating Private DNS Zone for APIM portal
module privatednsportalazureapinet 'modules/vnet/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsportalazureapinet'
  params: {
    privateDNSZoneName: 'portal.azure-api.net'
  }
}

// Linking Private DNS Zone for APIM portal to Hub VNet
module privatednsportalazureapinetLink 'modules/vnet/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsportalazureapinetLink'
  params: {
    privateDnsZoneName: privatednsportalazureapinet.outputs.privateDNSZoneName
    vnetId: vnethub.id
  }
}

// Creating Private DNS Zone for APIM developer
module privatednsdeveloperazureapinet 'modules/vnet/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsdeveloperazureapinet'
  params: {
    privateDNSZoneName: 'developer.azure-api.net'
  }
}

// Linking Private DNS Zone for APIM developer to Hub VNet
module privatednsdeveloperazureapinetLink 'modules/vnet/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsdeveloperazureapinetLink'
  params: {
    privateDnsZoneName: privatednsdeveloperazureapinet.outputs.privateDNSZoneName
    vnetId: vnethub.id
  }
}

// Creating Private DNS Zone for APIM management
module privatednsmanagementazureapinet 'modules/vnet/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsmanagementazureapinet'
  params: {
    privateDNSZoneName: 'management.azure-api.net'
  }
}

// Linking Private DNS Zone for APIM management to Hub VNet
module privatednsmanagementazureapinetLink 'modules/vnet/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsmanagementazureapinetLink'
  params: {
    privateDnsZoneName: privatednsmanagementazureapinet.outputs.privateDNSZoneName
    vnetId: vnethub.id
  }
}

// Creating Private DNS Zone for APIM scm
module privatednsscmazureapinet 'modules/vnet/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsscmazureapinet'
  params: {
    privateDNSZoneName: 'scm.azure-api.net'
  }
}

// Linking Private DNS Zone for APIM scm to Hub VNet
module privatednsscmazureapinetLink 'modules/vnet/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsscmazureapinetLink'
  params: {
    privateDnsZoneName: privatednsscmazureapinet.outputs.privateDNSZoneName
    vnetId: vnethub.id
  }
}

// FHIR DNZ Zones
// Creating Private DNS Zone for FHIR
module privatednsfhir 'modules/vnet/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsfhir'
  params: {
    privateDNSZoneName: 'privatelink.azurehealthcareapis.com'
  }
}

// Linking Private DNS Zone for FHIR to Hub VNet
module privatednsfhirLink 'modules/vnet/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsfhirLink'
  params: {
    privateDnsZoneName: privatednsfhir.outputs.privateDNSZoneName
    vnetId: vnethub.id
  }
}

// Creating NSG for AppGW Subnet
module nsgappgwsubnet 'modules/vnet/nsg.bicep' = {
  scope: resourceGroup(rg.name)
  name: nsgAppGWName
  params: {
    diagnosticWorkspaceId: logAnalyticsWorkspace.id
    location: location
    nsgName: nsgAppGWName
    securityRules: [
      {
        name: 'Allow443InBound'
        properties: {
          priority: 102
          sourceAddressPrefix: '*'
          protocol: 'Tcp'
          destinationPortRange: '443'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowControlPlaneV1SKU'
        properties: {
          priority: 110
          sourceAddressPrefix: 'GatewayManager'
          protocol: '*'
          destinationPortRange: '65503-65534'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowControlPlaneV2SKU'
        properties: {
          priority: 111
          sourceAddressPrefix: 'GatewayManager'
          protocol: '*'
          destinationPortRange: '65200-65535'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHealthProbes'
        properties: {
          priority: 120
          sourceAddressPrefix: 'AzureLoadBalancer'
          protocol: '*'
          destinationPortRange: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }

}

// Creating AppGW Route Table
module appgwroutetable 'modules/vnet/routetable.bicep' = {
  scope: resourceGroup(rg.name)
  name: rtAppGWSubnetName
  params: {
    location: location
    rtName: rtAppGWSubnetName
  }
}
resource appgwSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: '${vnetSpokeName}/${appGatewaySubnetName}'
}

module updateappgwNSG 'modules/vnet/attachNsg.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'AppGWSubnetNamensgupdate'
  params: {
    rtId: appgwroutetable.outputs.routetableID
    vnetName: vnetSpokeName
    subnetName: appGatewaySubnetName
    nsgId: nsgappgwsubnet.outputs.nsgID
    subnetAddressPrefix: appgwSubnet.properties.addressPrefix
    serviceep: 'Microsoft.Storage'
  }
  dependsOn: [
    vnetspoke
  ]
}

resource fhirSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: '${vnetSpokeName}/${FHIRSubnetName}'
}

module updatefhirNSG 'modules/vnet/attachNsg.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'FhirSubnetNamensgupdate'
  params: {
    rtId: routetable.outputs.routetableID
    vnetName: vnetSpokeName
    subnetName: FHIRSubnetName
    nsgId: nsgfhirsubnet.outputs.nsgID
    subnetAddressPrefix: fhirSubnet.properties.addressPrefix
    
  }
  dependsOn: [
    vnetspoke
    updateappgwNSG
  ]
}
