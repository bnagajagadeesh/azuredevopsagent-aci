param acrName string = 'craciazpagent'
param aciName string = 'ci-azpagent'
param location string = resourceGroup().location
param containerName string = 'ci-azpagent'
param imageName string = 'azpagent'
param imageTag string
param restartPolicy string = 'Always'
param gitRepositoryUrl string = 'https://github.com/bnagajagadeesh/azuredevopsagent-aci.git'
param gitBranch string = 'main'
param gitRepoDirectory string = 'ContainerInstanceWithPAT'
param acrBuildPlatform string = 'linux'
param azpToken string

// Create Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

module buildAcrImage 'br/public:deployment-scripts/build-acr:1.0.1' = {
  name: 'buildAcrImage-${replace(imageName,'/','-')}'
  params: {
    AcrName: acr.name
    location: location
    gitRepositoryUrl: gitRepositoryUrl
    gitBranch: gitBranch
    gitRepoDirectory: gitRepoDirectory
    imageName: imageName
    imageTag: imageTag
    acrBuildPlatform: acrBuildPlatform
  }
}

// Create Managed Identity
resource uai 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'uid-${aciName}'
  location: location
}

// Create Azure Container Instance with system assigned identity
resource aci 'Microsoft.ContainerInstance/containerGroups@2021-03-01' = {
  name: aciName
  location: location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${uai.id}': {}
    }
  }
  properties: {
    imageRegistryCredentials: [
      {
        server: acr.properties.loginServer
        username: acr.listCredentials().username
        password: acr.listCredentials().passwords[0].value
      }
    ]
    containers: [
      {
        name: '${containerName}1'
        properties: {
          image: buildAcrImage.outputs.acrImage
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
          environmentVariables: [
            {
              name: 'AZP_URL'
              value: 'https://dev.azure.com/106025/'
            }           
            {
              name: 'AZP_AGENT_NAME'
              value: 'containerinstance-azpagent1'
            }
            {
              name: 'AZP_POOL'
              value: 'selfhostedagentpool'
            }
            {
              name: 'AZP_TOKEN'
              value: azpToken
            }
          ]
        }
      }
      {
        name: '${containerName}2'
        properties: {
          image: '${acr.properties.loginServer}/${imageName}:${imageTag}'
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
          environmentVariables: [
            {
              name: 'AZP_URL'
              value: 'https://dev.azure.com/106025/'
            }           
            {
              name: 'AZP_AGENT_NAME'
              value: 'containerinstance-azpagent2'
            }
            {
              name: 'AZP_POOL'
              value: 'selfhostedagentpool'
            }
            {
              name: 'AZP_TOKEN'
              value: azpToken
            }
          ]
        }
      }
      {
        name: '${containerName}3'
        properties: {
          image: '${acr.properties.loginServer}/${imageName}:${imageTag}'
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
          environmentVariables: [
            {
              name: 'AZP_URL'
              value: 'https://dev.azure.com/106025/'
            }           
            {
              name: 'AZP_AGENT_NAME'
              value: 'containerinstance-azpagent3'
            }
            {
              name: 'AZP_POOL'
              value: 'selfhostedagentpool'
            }
            {
              name: 'AZP_TOKEN'
              value: azpToken
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: restartPolicy
  }
}

// Create ACR Pull Role Assignment for Managed Identity on Azure Container Registry
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(acr.id, uai.id, 'acrpull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull role
    principalId: uai.properties.principalId    
    principalType: 'ServicePrincipal'
  }
}
