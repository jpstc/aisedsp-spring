param location string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-aisedsp-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { family: 'A'; name: 'standard' }
    tenantId: tenant().tenantId
    enableRbacAuthorization: true
    enabledForTemplateDeployment: true
  }
}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uami-aisedsp'
  location: location
}

output kvName string = kv.name
output uamiId string = uami.id