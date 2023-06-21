
// Parameters
param location string
param RGName string
param managedIdentity object
param storageAccountName string

param subnet string

// Loading APIM API, since it requires to replace the backend Access at the API level, we are using Powershell with deployment scripts to load the Swagger API File and replace it prior to import at the APIM.
resource storageNetworkUpdate 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'Storage-network-update'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '6.6'
    arguments: ' -RG ${RGName} -storageAccountName ${storageAccountName} -subnet ${subnet} -subscriptionId ${subscription().subscriptionId}'
    scriptContent: '''
    param(
      [string] [Parameter(Mandatory=$true)] $RG,
      [string] [Parameter(Mandatory=$true)] $storageAccountName,
      [string] [Parameter(Mandatory=$true)] $subnet,
      [string] [Parameter(Mandatory=$true)] $subscriptionId
      )

      $ErrorActionPreference = 'Stop'
      $DeploymentScriptOutputs = @{}
      Login-AzAccount -Identity -SubscriptionId $subscriptionId
        
       
       Add-AzStorageAccountNetworkRule -ResourceGroupName $RG -Name $storageAccountName -VirtualNetworkResourceId $subnet

      update-AzStorageAccountNetworkRuleSet -ResourceGroupName $RG  -Name $storageAccountName -DefaultAction "Deny" 
       '''
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '/subscriptions/${managedIdentity.subscriptionId}/resourceGroups/${managedIdentity.resourceGroupName}/providers/${managedIdentity.resourceId}': {}
    }
  }
}
