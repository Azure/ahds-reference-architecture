// Parameters
param storageAccountName string
param queueName string

// defining Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: storageAccountName
}

resource createdefQueue 'Microsoft.Storage/storageAccounts/queueServices@2022-09-01' existing = {
  name: 'default'
  parent: storageAccount
  
}

resource createQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2022-09-01' = {
  name: queueName
  parent: createdefQueue
}

output queueId string = createQueue.id
