// Parameters
param hostingPlanName string
param location string
//param functionSKU string = 'B1'
param functionWorkers int = 5

// Variables
var skuName = 'EP1'
var skuTier = 'ElasticPremium'
var skusize = 'EP1'
var skufamily = 'EP'
var skucapacity = 1

// Creating App Service Plan
resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: skuName
    tier: skuTier
    size: skusize
    family: skufamily
    capacity: skucapacity
}
  kind: 'elastic'
  properties: {
    reserved: false
    maximumElasticWorkerCount: functionWorkers
  }
}

// Outputs
output serverfarmid string = hostingPlan.id
output serverfarmname string = hostingPlan.name
