param location string
param envName string
param kvName string
param sqlConnSecretName string
param sbConnSecretName string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = { name: kvName }

resource logws 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-aisedsp-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
  }
}

resource env 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: envName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logws.properties.customerId
        sharedKey: listKeys(logws.id, '2020-08-01').primarySharedKey
      }
    }
  }
}

var sqlSecretUri = reference(resourceId('Microsoft.KeyVault/vaults/secrets', kv.name, sqlConnSecretName), '2023-07-01').properties.secretUriWithVersion
var sbSecretUri  = reference(resourceId('Microsoft.KeyVault/vaults/secrets', kv.name, sbConnSecretName), '2023-07-01').properties.secretUriWithVersion

resource mzv 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'mzv-service'
  location: location
  properties: {
    environmentId: env.id
    configuration: {
      ingress: { external: true, targetPort: 8080 }
      secrets: [
        { name: 'sql-conn', value: '@Microsoft.KeyVault(SecretUri=${sqlSecretUri})' }
        { name: 'sb-conn',  value: '@Microsoft.KeyVault(SecretUri=${sbSecretUri})' }
      ]
      registries: []
    }
    template: {
      containers: [
        {
          name: 'mzv'
          image: 'REPLACED_BY_AZD'
          env: [
            { name: 'SQL_CONN', secretRef: 'sql-conn' }
            { name: 'SB_CONN',  secretRef: 'sb-conn' }
            { name: 'SB_TOPIC', value: 'doc-status' }
          ]
        }
      ]
    }
  }
}

resource stc 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'stc-cdbp'
  location: location
  properties: {
    environmentId: env.id
    configuration: {
      ingress: { external: true, targetPort: 8081 }
      secrets: [
        { name: 'sql-conn', value: '@Microsoft.KeyVault(SecretUri=${sqlSecretUri})' }
        { name: 'sb-conn',  value: '@Microsoft.KeyVault(SecretUri=${sbSecretUri})' }
      ]
    }
    template: {
      containers: [
        {
          name: 'stc'
          image: 'REPLACED_BY_AZD'
          env: [
            { name: 'SQL_CONN', secretRef: 'sql-conn' }
            { name: 'SB_CONN',  secretRef: 'sb-conn' }
            { name: 'SB_TOPIC', value: 'doc-status' }
            { name: 'SB_SUB',   value: 'stc-cdbp' }
          ]
        }
      ]
    }
  }
}

output mzvUrl string = 'https://${mzv.name}.${env.properties.defaultDomain}'
output stcUrl string = 'https://${stc.name}.${env.properties.defaultDomain}'
