param location string
param mzvBackendUrl string
param stcBackendUrl string

resource apim 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: 'apim-aisedsp-${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Developer', capacity: 1 }
  properties: {
    publisherEmail: 'admin@example.com'
    publisherName: 'aisedsp'
  }
}

// Create APIs with basic settings; detailed policies applied by postprovision script
resource apiMzv 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  name: '${apim.name}/mzv'
  properties: {
    path: 'mzv'
    protocols: [ 'https' ]
    displayName: 'MZV API'
  }
}

resource apiStc 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  name: '${apim.name}/stc'
  properties: {
    path: 'stc'
    protocols: [ 'https' ]
    displayName: 'STC API'
  }
}

// Backends
resource beMzv 'Microsoft.ApiManagement/service/backends@2022-08-01' = if (!empty(mzvBackendUrl)) {
  name: '${apim.name}/backend-mzv'
  properties: {
    url: mzvBackendUrl
    protocol: 'http'
  }
}

resource beStc 'Microsoft.ApiManagement/service/backends@2022-08-01' = if (!empty(stcBackendUrl)) {
  name: '${apim.name}/backend-stc'
  properties: {
    url: stcBackendUrl
    protocol: 'http'
  }
}

output gatewayUrl string = 'https://${apim.name}.azure-api.net'