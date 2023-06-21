param storageAccountName string
param queueName string
param subjectbegins string
param subjectends string

// defining Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: storageAccountName
}


resource ndjsonSubscription 'Microsoft.EventGrid/eventSubscriptions@2022-06-15' = {
  scope: storageAccount
  name: queueName
  properties: {
    destination: {
      endpointType: 'StorageQueue'
      // For remaining properties, see EventSubscriptionDestination objects
      properties: {
        queueName: queueName
        resourceId: storageAccount.id
      }
    }
    filter: {
      advancedFilters: [
        {
          operatorType: 'StringIn'
          key: 'data.api'
          values: [
            'CopyBlob', 'PutBlob', 'PutBlockList', 'FlushWithClose'
          ]
          // For remaining properties, see AdvancedFilter objects
        }
      ]
      subjectBeginsWith: subjectbegins
      subjectEndsWith: subjectends
    }
  }
}
