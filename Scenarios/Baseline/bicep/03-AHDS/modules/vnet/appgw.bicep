// Parameters
param appgwname string
param subnetid string
param appgwpip string
param location string = resourceGroup().location
param appGwyAutoScale object
param appGatewayFQDN string = 'api.example.com'
param primaryBackendEndFQDN string
param appGatewayIdentityId string
param storageFQDN string

@secure()
param keyVaultSecretId string

param availabilityZones array
param probeUrl string = '/status-0123456789abcdef'

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 365

@description('Optional. Resource ID of the diagnostic log analytics workspace. For security reasons, it is recommended to set diagnostic settings to send data to either storage account, log analytics workspace or event hub.')
param diagnosticWorkspaceId string

@description('Optional. The name of logs that will be streamed. "allLogs" includes all possible logs for the resource.')
@allowed([
  'allLogs'
  'ApplicationGatewayAccessLog'
  'ApplicationGatewayPerformanceLog'
  'ApplicationGatewayFirewallLog'
])
param diagnosticLogCategoriesToEnable array = [
  'allLogs'
]

@description('Optional. The name of metrics that will be streamed.')
@allowed([
  'AllMetrics'
])
param diagnosticMetricsToEnable array = [
  'AllMetrics'
]

@description('Optional. The name of the diagnostic setting, if deployed.')
param diagnosticSettingsName string = '${appgwname}-diagnosticSettings-001'

// Variables
var frontendPortNameHTTP = 'HTTP-80'
var frontendPortNameHTTPs = 'HTTPs-443'
var frontendIPConfigurationName = 'appGatewayFrontendIP'
var httplistenerName = 'httplistener'
var httpslistenerName = 'httpslistener'
var backendAddressFhirPoolName = 'backend-fhir-pool'
var backendAddressSaPoolName = 'backend-storage-pool'
var backendHttpSettingsCollectionName = 'backend-http-settings'
var backendHttpsSettingsCollectionName = 'backend-https-settings'
var backendSaSettingsCollectionName = 'backend-Storage-settings'

var diagnosticsLogsSpecified = [for category in filter(diagnosticLogCategoriesToEnable, item => item != 'allLogs'): {
  category: category
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]

var diagnosticsLogs = contains(diagnosticLogCategoriesToEnable, 'allLogs') ? [
  {
    categoryGroup: 'allLogs'
    enabled: true
    retentionPolicy: {
      enabled: true
      days: diagnosticLogsRetentionInDays
    }
  }
] : diagnosticsLogsSpecified

var diagnosticsMetrics = [for metric in diagnosticMetricsToEnable: {
  category: metric
  timeGrain: null
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]

// Creating Application Gateway
resource appgw 'Microsoft.Network/applicationGateways@2021-02-01' = {
  name: appgwname
  location: location
  zones: !empty(availabilityZones) ? availabilityZones : null
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appGatewayIdentityId}': {}
    }
  }
  properties: {
    autoscaleConfiguration: !empty(appGwyAutoScale) ? appGwyAutoScale : null
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: empty(appGwyAutoScale) ? 2 : null
    }
    gatewayIPConfigurations: [
      {
        name: 'appgw-ip-configuration'
        properties: {
          subnet: {
            id: subnetid
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: frontendIPConfigurationName
        properties: {
          publicIPAddress: {
            id: appgwpip
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: frontendPortNameHTTP
        properties: {
          port: 80
        }
      }
      {
        name: frontendPortNameHTTPs
        properties: {
          port: 443
        }
      }
    ]
    sslCertificates: [
      {
        name: appGatewayFQDN
        properties: {
          keyVaultSecretId: keyVaultSecretId
        }
      }
    ]
    sslPolicy: {
      minProtocolVersion: 'TLSv1_2'
      policyType: 'Custom'
      cipherSuites: [
        'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256'
        'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'
        'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256'
        'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384'
        'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256'
        'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384'
      ]
    }
    backendAddressPools: [
      { 
        id: backendAddressFhirPoolName
        name: backendAddressFhirPoolName
        properties: {
          backendAddresses: [
            {
              fqdn: primaryBackendEndFQDN
            }
          ]
        }
      }
      {
        id: backendAddressSaPoolName
        name: backendAddressSaPoolName
        properties: {
          backendAddresses: [
            {
              fqdn: storageFQDN
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: backendHttpSettingsCollectionName
        properties: {
          cookieBasedAffinity: 'Disabled'
          path: '/'
          port: 80
          protocol: 'Http'
          requestTimeout: 60
        }
      }
      {
        name: backendHttpsSettingsCollectionName
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          hostName: primaryBackendEndFQDN
          pickHostNameFromBackendAddress: false
          requestTimeout: 30
          probe: {
            //id: '${resourceId('Microsoft.Network/applicationGateways', appgwname)}/probes/APIM'
            id: resourceId('Microsoft.Network/applicationGateways/probes', appgwname, 'APIM')
          }
        }
      }
      {
        name: backendSaSettingsCollectionName
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          hostName: storageFQDN
          pickHostNameFromBackendAddress: false
          requestTimeout: 30
          probe: {
            //id: '${resourceId('Microsoft.Network/applicationGateways', appgwname)}/probes/APIM'
            id: resourceId('Microsoft.Network/applicationGateways/probes', appgwname, 'Storage')
          }
        }
      }
    ]
    httpListeners: [
      {
        name: httplistenerName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appgwname, frontendIPConfigurationName)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appgwname, frontendPortNameHTTP)
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
      {
        name: httpslistenerName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appgwname, frontendIPConfigurationName)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appgwname, frontendPortNameHTTPs)
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appgwname, appGatewayFQDN)
          }
          hostNames: []
          requireServerNameIndication: false
        }
      }
    ]
    urlPathMaps: [
      {
        name: 'path-redirect'
        properties: {
          defaultBackendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appgwname,backendAddressSaPoolName)
          }
          defaultBackendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appgwname,backendSaSettingsCollectionName)
          }
          pathRules: [
            {
              name: 'ahds'
              properties: {
                paths: [
                  '/fhir'
                ]
                backendAddressPool: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appgwname,backendAddressFhirPoolName)
                }
                backendHttpSettings: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appgwname,backendHttpsSettingsCollectionName)
                }
              }
            }
            {
              name: 'ahds-default'
              properties: {
                paths: [
                  '/fhir/*'
                ]
                backendAddressPool: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appgwname,backendAddressFhirPoolName)
                }
                backendHttpSettings: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appgwname,backendHttpsSettingsCollectionName)
                }
              }
            }
            {
              name: 'default'
              properties: {
                paths: [
                  '/*'
                ]
                backendAddressPool: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appgwname,backendAddressSaPoolName)
                }
                backendHttpSettings: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appgwname,backendSaSettingsCollectionName)
                }
              }
            }
          ]
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'fhir'
        properties: {
          ruleType: 'PathBasedRouting'
          priority: 101
          
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appgwname, httpslistenerName)
          }
          
          urlPathMap: {
            id: resourceId('Microsoft.Network/applicationGateways/urlPathMaps', appgwname,'path-redirect' )
          }
        }
      }
    ]
    
    probes: [
      {
        name: 'APIM'
        properties: {
          protocol: 'Https'
          host: primaryBackendEndFQDN
          path: probeUrl
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
          minServers: 0
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
      {
        name: 'Storage'
         properties: {
          protocol: 'Https'
          host: storageFQDN
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
        minServers: 0
          match: {
            statusCodes: [
              '400'
            ]
        }
     }  
}
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Detection'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.0'
      disabledRuleGroups: []
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    enableHttp2: true
  }
}

// Defining Application Gateway Diagnostic Settings
resource applicationGateway_diagnosticSettingName 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingsName
  properties: {
    workspaceId: diagnosticWorkspaceId
    metrics: diagnosticsMetrics
    logs: diagnosticsLogs
  }
  scope: appgw
}
