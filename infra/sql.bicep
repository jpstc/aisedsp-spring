param location string
param kvName string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = { name: kvName }

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: 'sql-aisedsp-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'ChangeMe-12345!'
    publicNetworkAccess: 'Enabled'
  }
}

resource db 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  name: '${sqlServer.name}/db-aisedsp'
  location: location
  sku: { name: 'GP_S_Gen5_1'; tier: 'GeneralPurpose' }
  properties: { autoPauseDelay: 60; minCapacity: 0.5 }
}

var sqlConn = 'Server=tcp:${sqlServer.name}.database.windows.net,1433;Initial Catalog=${db.name};Authentication=Active Directory Default;Encrypt=True;'

resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${kv.name}/SQL-CONN'
  properties: { value: sqlConn }
}

output sqlConnSecretName string = last(split(secret.name, '/'))