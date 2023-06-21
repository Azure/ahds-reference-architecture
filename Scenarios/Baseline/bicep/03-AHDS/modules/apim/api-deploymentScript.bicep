
// Parameters
param location string
param serviceUrl string
param APIpath string = 'fhir'
param APIFormat string = 'Swagger'
param ApiUrlPath string
param APIMName string
param RGName string
param managedIdentity object

// Loading APIM API, since it requires to replace the backend Access at the API level, we are using Powershell with deployment scripts to load the Swagger API File and replace it prior to import at the APIM.
resource appGatewayCertificate 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'APIM-import-API'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '6.6'
    arguments: ' -RG ${RGName} -APIMName ${APIMName} -serviceUrl ${serviceUrl} -APIPath ${APIpath}  -APIFormat ${APIFormat} -ApiUrlPath ${ApiUrlPath} -subscriptionId ${subscription().subscriptionId}'
    scriptContent: '''
    param(
      [string] [Parameter(Mandatory=$true)] $RG,
      [string] [Parameter(Mandatory=$true)] $APIMName,
      [string] [Parameter(Mandatory=$true)] $serviceUrl,
      [string] [Parameter(Mandatory=$true)] $APIPath,
      [string] [Parameter(Mandatory=$true)] $APIFormat,
      [string] [Parameter(Mandatory=$true)] $ApiUrlPath,
      [string] [Parameter(Mandatory=$true)] $subscriptionId
      )

      $ErrorActionPreference = 'Stop'
      $DeploymentScriptOutputs = @{}
      Login-AzAccount -Identity -SubscriptionId $subscriptionId
      $destination = 'AHDS-Swagger.json'
      $destinationReplace = 'AHDS-Swagger-Replace.json'
      try {
          Invoke-RestMethod -Uri $ApiUrlPath -OutFile $destination -StatusCodeVariable result
      }
      catch {
          Write-Error "Unable to download $ApiUrlPath. Error: $($Error[0])"
          throw
      }
      ((Get-Content -path $destination -Raw) -replace 'XXXXXXXXXXXXXXXXXXXXXXX',$serviceUrl) | Set-Content -Path $destinationReplace
      #az apim api import -g $RG --service-name $APIMName --path $APIPath --specification-format $APIFormat --specification-path $destinationReplace

      # Get context of the API Management instance.
      $context = New-AzApiManagementContext -ResourceGroupName $RG -ServiceName $APIMName

      # Import API
      Import-AzApiManagementApi -Context $context -SpecificationFormat $APIFormat -SpecificationPath $destinationReplace -Path $APIPath
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
