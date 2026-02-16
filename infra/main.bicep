param location string = resourceGroup().location
param environmentName string = 'aisedsp-spring-${uniqueString(resourceGroup().id)}'

module kvMi './kv-mi.bicep' = {
  name: 'kv-mi'
  params: { location: location }
}

module sql './sql.bicep' = {
  name: 'sql'
  params: {
    location: location
    kvName: kvMi.outputs.kvName
  }
}

module sb './sb.bicep' = {
  name: 'servicebus'
  params: {
    location: location
    kvName: kvMi.outputs.kvName
  }
}

module aca './aca.bicep' = {
  name: 'containerapps'
  params: {
    location: location
    envName: environmentName
    kvName: kvMi.outputs.kvName
    sqlConnSecretName: sql.outputs.sqlConnSecretName
    sbConnSecretName: sb.outputs.sbConnSecretName
  }
}

module apim './apim.bicep' = {
  name: 'apim'
  params: {
    location: location
    mzvBackendUrl: aca.outputs.mzvUrl
    stcBackendUrl: aca.outputs.stcUrl
  }
}

output apimGatewayUrl string = apim.outputs.gatewayUrl
output mzvUrl string = aca.outputs.mzvUrl
output stcUrl string = aca.outputs.stcUrl