targetScope = 'subscription'
// Parameters
param rgName string
param vnetSubnetName string
param vnetName string
param vmSize string
param location string = deployment().location
param adminUsername string = 'jumpboxadmin'
param resourceSuffix string

// Defining VM Subnet
resource subnetVM 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  scope: resourceGroup(rgName)
  name: '${vnetName}/${vnetSubnetName}'
}

// Defining Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  scope: resourceGroup(rgName)
  name: 'log-${resourceSuffix}'
}

// Creating Jump Box VM
module jumpbox 'modules/VM/virtualmachine.bicep' = {
  scope: resourceGroup(rgName)
  name: 'jumpbox'
  params: {
    location: location
    subnetId: subnetVM.id
    vmSize: vmSize
    secrets: {
      user: {
        name: 'adminUsername'
        value: adminUsername
      }
      password: {
        name: 'adminPassword'
        value: guid(subscription().id)
      }
    }
    diagnosticWorkspaceId: logAnalyticsWorkspace.id
  }
}
