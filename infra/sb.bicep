param location string
param kvName string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = { name: kvName }

resource ns 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: 'sb-aisedsp-${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard' }
}

resource topic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  name: '${ns.name}/doc-status'
}

resource sub 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  name: '${ns.name}/doc-status/stc-cdbp'
}

@secure()
var sbConn = listKeys(resourceId('Microsoft.ServiceBus/namespaces/AuthorizationRules', ns.name, 'RootManageSharedAccessKey'), '2017-04-01').primaryConnectionString

resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${kv.name}/SB-CONN'
  properties: { value: sbConn }
}

output sbConnSecretName string = last(split(secret.name, '/'))